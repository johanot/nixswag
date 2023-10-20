let
  lib = import <nixpkgs/lib>;
  swagLib = import ./lib.nix {};

  containers = swagLib.testArgoCD.k8sLib.collectAll (a: (a._apiType or "") == "io.k8s.api.core.v1.Container");
in
{
  containers = lib.unique (map (c: c.image) containers);

  mapContainers = swagLib.testArgoCD.k8sLib.mapAPIType "io.k8s.api.core.v1.Container" (c: c // 
    {
      image =
        let
          parts = lib.filter (l: l != []) (builtins.split "\/" c.image.content);
          withoutRegistry = lib.drop 1 parts;
          replacementRegistry = "registry.nnitgroup.com";
        in
          "${replacementRegistry}/${lib.concatStringsSep "/" withoutRegistry}";
    }); 
}