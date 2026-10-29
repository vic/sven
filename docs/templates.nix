# Every example with a flake.nix is a flake template. Pure and cheap: no inputs, no yen evaluation.
# Both flakes use it: docs/flake.nix and the repository root flake.nix.
let
  root = ./examples;
  isTemplate = n: t: t == "directory" && builtins.pathExists (root + "/${n}/flake.nix");
  names = builtins.filter (n: isTemplate n (builtins.readDir root).${n}) (
    builtins.attrNames (builtins.readDir root)
  );
in
builtins.listToAttrs (
  map (n: {
    name = n;
    value = {
      path = root + "/${n}";
      inherit ((import (root + "/${n}/page.nix"))) description;
    };
  }) names
)
