#: lib.batteries.docs.templates :: { root; description; } -> templates -- flake templates from the directories of root that have a flake.nix
# flake templates from the directories of `root` that have a flake.nix; `description` reads a directory's path.
#   templates = docs.templates { root = ./examples; description = d: (import (d + "/page.nix")).description; };
{ root, description }:
let
  b = builtins;
  dirs = b.readDir root;
  names = b.filter (n: dirs.${n} == "directory" && b.pathExists (root + "/${n}/flake.nix")) (
    b.attrNames dirs
  );
in
b.listToAttrs (
  map (n: {
    name = n;
    value = {
      path = root + "/${n}";
      description = description (root + "/${n}");
    };
  }) names
)
