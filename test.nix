let
  lib = import <nixpkgs/lib>;
  swagLib = import ./lib.nix {};

  containers = swagLib.testArgoCD.k8sLib.collectAll (a: (a._apiType or "") == "io.k8s.api.core.v1.Container");
in
  lib.unique
    (map (c: c.image) containers)
