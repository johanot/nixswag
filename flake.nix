{
  description = "nixswag";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@attrs:
  let
    pname = "nixswag";
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
    };

    lib = pkgs.lib;
  in {
    nixosModules.default = import ./module.nix;

    devShell.${system} = pkgs.mkShell {
      buildInputs = with pkgs; [
        nixfmt
        yq-go
      ];
    };
  };
}
