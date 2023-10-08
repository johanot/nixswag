let
  lib = import <nixpkgs/lib> {};
  swagLib = import ./lib.nix {};
in
  swagLib.testK8sDeployment.k8sLib.collect