{ config, lib, ... }: with lib.types;
let
  cfg = config.nixswag;

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
            ref =
              if args.config."$ref" == null
              then ""
              else lib.removePrefix "#/definitions/" args.config."$ref";
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

      description = lib.mkOption {
        default = null;
        type = nullOr str;
      };

      properties = lib.mkOption {
        type = attrsOf property;
        default = {};
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
            collect = f: {

            };
            k8sAttrs = a:
              lib.attrValues (lib.filterAttrs (n: _: !(lib.hasPrefix "_" n)) a);

            mapRecursive = f: lib.flatten (mapRecursive' (k8sAttrs args.config.k8s) f);
            mapRecursive' = with builtins; subject: f:
              map (e: if isAttrs e then
                  mapRecursive' (k8sAttrs e) f
                else if isList e then
                  mapRecursive' e f
                else f e) subject;
          };
        };
      };
    });
  };

}
