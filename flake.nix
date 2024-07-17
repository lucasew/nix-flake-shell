{
  description = "nix-shell, but for flakes";
  inputs = {
    nixpkgs_bootstrap.url = "github:nixos/nixpkgs";

    flake-utils_bootstrap.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils_bootstrap, ... }:
  flake-utils_bootstrap.lib.eachDefaultSystem (system: {
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
