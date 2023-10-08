{ pkgs ? (import <nixpkgs> {}), ... }: rec{

  lib = pkgs.lib;
  
  loadFromUrl = with builtins; url: (fromJSON (readFile (fetchurl url)));
  
  init = api: k8s: (lib.evalModules {
    modules = [ (import ./module.nix) ({...}: {
      config.nixswag = { inherit api k8s; };
    })];
  }).config.nixswag;

  test = url: data: init (builtins.trace "hello" (loadFromUrl url)) data;

  #prefix: expr: lib.mapAttrs' (n: value: { name = lib.removePrefix "${prefix}." n; inherit value; }) expr.definitions;
}
