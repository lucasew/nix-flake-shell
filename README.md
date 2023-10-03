# nix-flake-shell

Like nix-shell, but for flakes.

Example:

```bash
nix run github:lucasew/nix-flake-shell -- nixpkgs=nixpkgs/release-23.05 nixpkgs.python3Packages.{numpy,pandas,jupyter} -- jupyter notebook
```
