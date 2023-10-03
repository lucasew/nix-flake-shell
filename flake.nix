{
  description = "nix-shell, but for flakes";
  inputs = {
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
  };

  outputs = { self, nixpkgs-lib, ... }: {
    lib = {
      mkWrapper = import ./mkWrapper.nix {
        flake = self;
      };
    };
  };
}
