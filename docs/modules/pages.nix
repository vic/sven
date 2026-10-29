# One page per directory of examples/. A directory is a flake template: flake.nix and modules/ (when the page has code),
# and page.nix (the prose). The docs evaluate the example's own flake.nix with the docs inputs, so the page shows what runs.
{
  yen,
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
  yen.page = lib.genAttrs slugs (
    slug:
    let
      p = metaOf slug;
    in
    {
      inherit (p) title description order;
      section = yen.section.${p.section};
      dir = root + "/${slug}";
    }
    // lib.optionalAttrs (p ? badge) { inherit (p) badge; }
    // lib.optionalAttrs (p ? route) { inherit (p) route; }
  );

  yen.helpers.example =
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
      engine = inputs.yen.lib; # stage, program, without: functions of a module
      page = import (dir + "/page.nix");
      # the eval result: every query of the example fleet
      result = if has "modules" then inputs.yen.lib.eval module else null;
      # the example with one more file (a `variants/` file, outside `modules/`): what a change does
      variant =
        f:
        inputs.yen.lib.eval {
          imports = [
            module
            (dir + "/${f}")
          ];
        };
      # only some files of the example: an early step of a migration
      only =
        fs:
        inputs.yen.lib.eval {
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
