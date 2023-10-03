{ flake
, system ? builtins.currentSystem
}:
args:
let
  items = builtins.foldl' (a: b: a // (let
    splitted = builtins.split "=" b;
    key = builtins.head (splitted);
    keyAndSep = key + "=";
    value = builtins.replaceStrings [ keyAndSep ] [ "" ] b;
    isKey = builtins.length splitted > 1;
  in if isKey then {
    inputs = a.inputs // { "${key}" = builtins.getFlake value; };
  } else {
    packages = a.packages ++ [ b ];
  })) {inputs.nixpkgs = builtins.getFlake "nixpkgs"; packages = [];} args;

  getKey = root: key: root.${key} or (getKey (root.outputs or root.legacyPackages or root.packages or root.${system} or (throw "unknown key")) key);

  getPackage = base: parts:
  if builtins.length parts == 0
    then base
    else getPackage (getKey base (builtins.head parts)) (builtins.tail parts);

  pathParts = path: builtins.filter (x: builtins.typeOf x == "string" && x != "") (builtins.split "\\." path);

  packages = map (key: getPackage root (pathParts key)) items.packages;

  root = items.inputs;

  callPackage = getPackage root [ "nixpkgs" "callPackage" ];

  mkShellWrapper = callPackage ./mkShellWrapper.nix { };

in mkShellWrapper {
  drv = {
    inherit packages;
    passthru = {
      inherit items getKey getPackage packages pathParts;
    };
  };
}

# { inputs ? {}
# , packages ? []
# }:


