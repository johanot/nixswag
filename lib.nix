{ pkgs ? (import <nixpkgs> {}), ... }: rec{

  lib = pkgs.lib;
  
  loadFromUrl = with builtins; url: (fromJSON (readFile (fetchurl url)));
  
  init = api: k8s: (lib.evalModules {
    modules = [ (import ./module.nix) ({...}: {
      config.nixswag = { inherit api k8s; };
    })];
  }).config.nixswag;

  test = url: data: init (loadFromUrl url) data;

  testK8s = test "https://raw.githubusercontent.com/kubernetes/kubernetes/master/api/openapi-spec/swagger.json";

  testK8sDeployment = testK8s { "deployment" = (builtins.fromJSON (builtins.readFile ./deployment.json)); };

  testArgoCD = with builtins; testK8s
    (lib.mapAttrs
      (n: _: fromJSON (readFile "${./argocd/${n}}"))
      (lib.filterAttrs (n: _: lib.hasSuffix ".json" n) (readDir ./argocd)));

  #prefix: expr: lib.mapAttrs' (n: value: { name = lib.removePrefix "${prefix}." n; inherit value; }) expr.definitions;
}
