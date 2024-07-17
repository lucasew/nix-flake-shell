{ flake
, system ? builtins.currentSystem
}:
args:

let
  pkgs = import flake.inputs.nixpkgs_bootstrap { inherit system; };
  inherit (pkgs) lib;

  scriptText = lib.readFile args;
  scriptLines = lib.splitString "\n" scriptText;
  scriptInterestLines = lib.filter (l: !(builtins.isNull (builtins.match "[\/ ]*#!nix-flake-shell[^$]*$" l))) scriptLines;

  scriptDirectives = map (l: builtins.head (builtins.match ".*!nix-flake-shell ([^$]*)" l)) scriptInterestLines;

  parseDirective = directive:
    let
      parts = builtins.match "([a-z]*) ([^$]*)" directive;
    in {
      command = lib.head parts;
      args = lib.head (lib.tail parts);
    };

  evalDirective = directive: prev:
    let
      parsed = if builtins.isString directive then parseDirective directive else directive;
      parsed' = parseDirective parsed.args;
      resultMap = {
        name = {
          name = if builtins.hasAttr "name" prev
            then throw "Name is being provided more than once"
            else parsed.args;
        };
        input = {
          input = prev.input // {
            "${parsed'.command}" =
              if builtins.hasAttr parsed'.command prev.input
              then throw "Input ${parsed'.command} is being provided more than once"
              else builtins.getFlake parsed'.args;
          };
        };
        prelude = {
          prelude = builtins.concatStringsSep "\n" [prev.prelude parsed.args];
        };
        prefix = {
          prefix =
            if builtins.hasAttr "prefix" prev
            then throw "Prefix directive is being provided twice"
            else parsed.args;
        };
        package = {
          package = (prev.package or []) ++ [ parsed.args ];
        };
      };

    resultMaterialized = resultMap."${parsed.command}";
    resultMaterializedCheck = if builtins.hasAttr parsed.command resultMap then resultMaterialized else throw "Invalid #!nix-flake-shell directive: ${parsed.command}";

  in prev // resultMaterializedCheck;

  evalInitialState = {
    input = flake.inputs;
    prelude = "";
  };

  evaluated = lib.foldr (evalDirective) evalInitialState scriptDirectives;

  deref = tree: path:
    if path == []
      then tree else
      if builtins.hasAttr (lib.head path) tree then
        deref (tree.${lib.head path}) (lib.tail path)
      else deref (tree.${system} or tree.legacyPackages) path;

  evaluated' = evaluated // {
    input = evaluated.input // {
      nixpkgs = evaluated.input.nixpkgs or evaluated.input.nixpkgs_bootstrap;
    };
    name = evaluated.name or "hashbang-script";
    package = map (p: deref evaluated'.input (lib.splitString "." p)) evaluated.package;
  };

  metadata = {
    inherit scriptLines;
    inherit scriptInterestLines;
    inherit scriptDirectives;
    inherit evaluated;
    inherit evaluated';
    parsedDirectives = map parseDirective scriptDirectives;
  };

  metadataJSON = pkgs.writeText "teste.json" (builtins.toJSON metadata);

  mkShellWrapper = pkgs.callPackage ./mkShellWrapper.nix { };

  entrypointScript = mkShellWrapper {
    drv = {
      packages = evaluated'.package;
    };
    inherit (evaluated') prelude;
    passthru = {evaluated = evaluated';};
  };

  hashbangScript = pkgs.writeShellScript evaluated'.name ''
    ${entrypointScript} ${evaluated'.prefix} "$@"
  '';

in hashbangScript.overrideAttrs (old: {
  passthru = (old.passthru or {}) // {
    evaluated = evaluated';
    inherit metadata;
    inherit metadataJSON;
  };
})
