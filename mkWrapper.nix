{ flake
, system ? builtins.currentSystem
}:
args:

let
  trace_it = v: builtins.trace v v;
  pkgs = import flake.inputs.nixpkgs_bootstrap { inherit system; };
  inherit (pkgs) lib;

  scriptText = lib.readFile args;
  scriptLines = lib.splitString "\n" scriptText;
  scriptInterestLines = lib.filter (l: !(builtins.isNull (builtins.match "[\/ ]*#!nix-flake-shell .*" l))) scriptLines;

  scriptDirectives = map (l: builtins.head (builtins.match "[\/ ]*#!nix-flake-shell *(.*)" l)) scriptInterestLines;

  parseDirective = directive:
    let
      parts = builtins.match "([a-zA-Z0-9_]*) (.*)" directive;
      invalidDirective = builtins.abort "Invalid directive: ${directive}";
    in if parts == null then {
      command = invalidDirective;
      args = invalidDirective;
    } else {
      command = lib.head parts;
      args = lib.head (lib.tail parts);
    };

  evalDirective = directive: prev:
    let
      parsed = if builtins.isString directive then parseDirective directive else directive;
      parsed' = parseDirective parsed.args;
      parsed'' = parseDirective parsed'.args;
      resultMap = {
        name = {
          name = if builtins.hasAttr "name" prev
            then throw "Name is being provided more than once"
            else parsed.args;
        };
        flake = {
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
          packages = prev.packages ++ [ parsed.args ];
        };
        fetch = {
          input = prev.input // {
            "${parsed'.command}" = if builtins.hasAttr parsed'.command prev.input
              then throw "Input ${parsed'.command} is being provided more than once"
              else let
                fetcher = deref pkgs (lib.splitString "." parsed''.command);
                argsStmts = lib.splitString " " parsed''.args;

                argReducer = arg: prev: 
                let
                  parts = builtins.match "([a-zA-Z\\_]*)=([^$]*)" arg;
                  key = lib.head parts;
                  value = lib.head (lib.tail parts);
                in if parts == null then abort "fetch/${parsed'.command}: Invalid key/value item near '${arg}'" else prev // {
                  ${key} = value;
                };
              in fetcher (lib.foldr (argReducer) {} argsStmts);
          };
        };
      };

    resultMaterialized = resultMap."${parsed.command}";
    resultMaterializedCheck = if builtins.hasAttr parsed.command resultMap then resultMaterialized else throw "Invalid #!nix-flake-shell directive: ${parsed.command}";

  in prev // resultMaterializedCheck;

  evalInitialState = {
    input = flake.inputs;
    prelude = "";
    packages = [];
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
    packages = map (p: deref evaluated'.input (lib.splitString "." p)) evaluated.packages;
    prelude = (builtins.concatStringsSep "\n" ([]
      ++ (builtins.attrValues (builtins.mapAttrs (k: v: "export INPUT_${k}=\"${v}\"") (builtins.removeAttrs evaluated'.input ["nixpkgs_bootstrap" "flake-utils_bootstrap"])))
      ++ [evaluated.prelude]
    )
    );
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
      inherit (evaluated') packages;
    };
    prelude = ''
      ${evaluated'.prelude}
      exec ${evaluated'.prefix or (throw "Missing prefix directive. Where this script will be run?")} "$@"
    '';
    passthru = {
      evaluated = evaluated';
      inherit metadata;
      inherit metadataJSON;
    };
  };
# in metadataJSON

in entrypointScript
