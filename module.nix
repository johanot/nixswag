{ config, lib, options, ... }: with lib.types;
let
  cfg = config.nixswag;

  rinse = c: lib.filterAttrs (n: _: !(lib.hasPrefix "_" n)) c;

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
      if isAttrs c then { content = mapAttrs traverseAttrs (rinse c); nixType = typeOf c; apiType = resolved.name; }
      else if isList c then { content = map (traverse resolved) c; nixType = typeOf c; itemType = resolved.name; }
      else { content = c; nixType = typeOf c; apiType = resolved.name; };

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

      _apiName = lib.mkOption {
        type = str;
        internal = true;
        readOnly = true;
        default = builtins.elemAt (builtins.split "\/" args.config.apiVersion) 0;
      };

      _apiVersion = lib.mkOption {
        type = str;
        internal = true;
        readOnly = true;
        default = builtins.elemAt (builtins.split "\/" args.config.apiVersion) 2;
      };

      _resolvedType = lib.mkOption {
        type = definition;
        internal = true;
        readOnly = true;
        default = cfg.api.definitions."io.k8s.api.${args.config._apiName}.${args.config._apiVersion}.${args.config.kind}";
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

        k8s = lib.mkOption {
          type = attrsOf k8sResource;
        };

        k8sLib = lib.mkOption {
          type = attrs;
          default = rec{
            collect = lib.collect (v: (v.itemType or "") == "io.k8s.api.core.v1.Container") walk;
            walk = lib.mapAttrs (_: v: traverse v._resolvedType v) args.config.k8s;

              #lib.foldr (a: b: if f a then b ++ [a] else b) [] subject;
          };
        };
      };
    });
  };

}
