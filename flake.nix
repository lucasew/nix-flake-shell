{
  description = "nix-shell, but for flakes";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (system: {
      lib = {
        mkWrapper = import ./mkWrapper.nix {
          flake = self;
          inherit system;
        };
      };
      apps.default = {
        type = "app";
        program = ./entrypoint;
      };
  });
}
