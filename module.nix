{ config, lib, options, ... }: with lib.types;
let
  cfg = config.nixswag;

  rinse = c: if builtins.isAttrs c then lib.filterAttrs (n: _: !(lib.hasPrefix "_" n)) c else c;

  traverse = with lib; with builtins; t: c:
    let
      resolved = (if (t == null || t == {}) then { name = "primitive"; } else t);
      traverseAttrs = n: v:
        let
          prop = resolved._properties.${n} or {};
          propType = prop._resolvedType or null;
        in
          traverse propType v;
    in
      if isAttrs c then { content = mapAttrs traverseAttrs (rinse c); _nixType = typeOf c; _apiType = resolved.name; }
      else if isList c then { content = map (traverse resolved) c; _nixType = typeOf c; _itemType = resolved.name; }
      else { content = c; _nixType = typeOf c; _apiType = resolved.name; };

  collect' = with builtins; f: v:
    (if isAttrs v && f v then [ v ] else [])
    ++
    (if isAttrs v && v ? content then collect' f v.content
     else if isAttrs v then lib.concatMap (collect' f) (lib.attrValues v)
     else if isList v then lib.concatMap (collect' f) v
     else []);

  render' = with builtins; v:
    (if isAttrs v && v ? content then render' v.content
     else if isAttrs v then mapAttrs (_: v: render' v) v
     else if isList v then map render' v
     else rinse v);

  property = submodule (args@{ name, ... }: {
    freeformType = oneOf [ attrs (listOf str) ];

    options = {

      description = lib.mkOption {
        default = null;
        type = nullOr str;
      };

      "$ref" = lib.mkOption {
        default = null;
        type = nullOr str;
      };

      _resolvedType = lib.mkOption {
        type = nullOr definition;
        internal = true;
        default = 
          let
            normalize = lib.removePrefix "#/definitions/";
            items = args.config.items or {};
            ref =
              if args.config."$ref" != null then normalize args.config."$ref"
              else if (items."$ref" or null) != null then normalize args.config.items."$ref"
              else "";
          in
            cfg.api.definitions.${ref} or null;
      };

      _properties = lib.mkOption {
        type = nullOr (attrsOf property);
        internal = true;
        default = (args.config._resolvedType or {}).properties or null;
      };

      type = lib.mkOption {
        default = null;
        type = nullOr (enum [
          "array"
          "boolean"
          "integer"
          "number"
          "object"
          "string"
        ]);
      };
    };
  });

  definition = submodule (args@{ name, ... }: {
    freeformType = attrs;

    options = {

      name = lib.mkOption {
        default = name;
        type = str;
      };

      description = lib.mkOption {
        default = null;
        type = nullOr str;
      };

      properties = lib.mkOption {
        type = attrsOf property;
        default = {};
      };

      _properties = lib.mkOption {
        type = attrsOf property;
        default = args.config.properties;
      };

    };
  });

  k8sResource = submodule (args@{ name, ... }: {
    freeformType = oneOf [attrs int str];
    
    options = {
      apiVersion = lib.mkOption {
        type = str;
      };

      kind = lib.mkOption {
        type = str;
      };

      _apiParts = lib.mkOption {
        type = listOf str;
        internal = true;
        readOnly = true;
        default = builtins.split "\/" args.config.apiVersion;
      };

      _apiGroup = lib.mkOption {
        type = str;
        internal = true;
        readOnly = true;
        default = with builtins;
          let
            parts = args.config._apiParts;
            hasGroup = length parts > 1;
          in
            if hasGroup then elemAt parts 0
            else "";
      };

      _apiVersion = lib.mkOption {
        type = str;
        internal = true;
        readOnly = true;
        default = with builtins;
          let
            parts = args.config._apiParts;
            hasGroup = length parts > 1;
          in
            if hasGroup then elemAt parts 2
            else elemAt parts 0;
      };

      _resolvedType = lib.mkOption {
        type = definition;
        internal = true;
        readOnly = true;
        default = cfg.api.k8s."${args.config._apiGroup}//${args.config._apiVersion}//${args.config.kind}";
      };

      _properties = lib.mkOption {
        type = nullOr (attrsOf property);
        internal = true;
        default = (args.config._resolvedType or {}).properties or null;
      };
    };
  });
in {

  options.nixswag = lib.mkOption {
    type = submodule (args@{...}: {
      freeformType = attrs;
      
      options = {
        api.definitions = lib.mkOption {
          type = attrsOf definition;
        };

        api.k8s = lib.mkOption {
          type = attrsOf definition;
          default = lib.mapAttrs' (_: v: let x = builtins.head v.x-kubernetes-group-version-kind; in {
            name = "${x.group}//${x.version}//${x.kind}";
            value = v;
          }) (lib.filterAttrs (_: v: v ? x-kubernetes-group-version-kind) args.config.api.definitions);
        };

        k8s = lib.mkOption {
          type = attrsOf k8sResource;
        };

        k8sEnriched = lib.mkOption {
          type = attrsOf k8sResource;
          default = lib.mapAttrs (_: v: traverse v._resolvedType v) args.config.k8s;
          readOnly = true;
          internal = true;
        };

        k8sLib = lib.mkOption {
          type = attrs;
          default = rec{
            collectAll = f: builtins.concatLists (lib.attrValues (collect f));
            collect = f: lib.mapAttrs (_: v: render' (collect' f v)) args.config.k8sEnriched;
            render = render';
          };
        };
      };
    });
  };

}
