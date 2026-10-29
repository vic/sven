# One page per directory of examples/. A directory is a flake template: flake.nix and modules/ (when the page has code),
# and page.nix (the prose). The docs evaluate the example's own flake.nix with the docs inputs, so the page shows what runs.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  root = ../examples;
  slugs = lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir root));
  metaOf = slug: import (root + "/${slug}/page.nix");
in
{
  sven.page = lib.genAttrs slugs (
    slug:
    let
      p = metaOf slug;
    in
    {
      inherit (p) title description order;
      section = sven.section.${p.section};
      dir = root + "/${slug}";
    }
    // lib.optionalAttrs (p ? badge) { inherit (p) badge; }
    // lib.optionalAttrs (p ? route) { inherit (p) route; }
  );

  sven.helpers.example =
    dir:
    let
      has = f: builtins.pathExists (dir + "/${f}");
      module = {
        imports = [ (inputs.import-tree (dir + "/modules")) ];
        _module.args = {
          inherit inputs;
          inherit (inputs.nixpkgs) lib;
        };
      };
    in
    {
      inherit dir inputs module;
      engine = inputs.sven.lib; # stage, program, without: functions of a module
      page = import (dir + "/page.nix");
      # the eval result: every query of the example fleet
      r = if has "modules" then inputs.sven.lib.eval module else null;
      # the example with one more file (a `variants/` file, outside `modules/`): what a change does
      variant =
        f:
        inputs.sven.lib.eval {
          imports = [
            module
            (dir + "/${f}")
          ];
        };
      # only some files of the example: an early step of a migration
      only =
        fs:
        inputs.sven.lib.eval {
          imports = map (f: dir + "/${f}") fs;
          _module.args = module._module.args;
        };
      # the example's flake outputs, from its own flake.nix
      flake =
        if has "flake.nix" then (import (dir + "/flake.nix")).outputs (inputs // { self = dir; }) else null;
      template = has "flake.nix";
      inputsKnown =
        !has "flake.nix" || lib.all (n: inputs ? ${n}) (lib.attrNames (import (dir + "/flake.nix")).inputs);
    };
}
