# The docs site as a yen fleet. The root `site` spawns one scope per page. Sections are data.
# Each page gives repo files (the .mdx), a sidebar entry, its template and its tests; the site reduces them to flake outputs.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) is;
  inherit (yen.lib.reduce) merge list;
  str = lib.types.str;
  int = lib.types.int;
in
{
  yen.kinds.section.fields = {
    title = str;
    order = int;
  };
  yen.kinds.page.fields = {
    title = str;
    description = str;
    section = yen.kinds.section;
    order = int;
    dir = is builtins.isPath; # the example directory: a flake template
    badge = yen.lib.maybe str; # a sidebar badge: "new", "advanced"
    route = yen.lib.derive str (self: "${self.section.name}/${self.name}"); # the route
  };
  yen.kinds.site = {
    spawns.page = _: yen.page;
    sinks = {
      out.reduce = merge;
      sidebar = {
        reduce = list;
        of = is (v: v ? section && v ? item);
      };
      # `nix flake check` runs the oracles too: one check for the fast ones, one for the NixOS evaluations
      tests = {
        reduce = merge;
        out =
          { tests, ... }:
          let
            failed =
              k:
              lib.concatLists (
                lib.mapAttrsToList (
                  p: t: map (c: "${p}/${c}") (lib.attrNames (lib.filterAttrs (_: ok: !ok) t.${k}))
                ) tests
              );
            check =
              k:
              inputs.nixpkgs.legacyPackages.x86_64-linux.runCommand "docs-${k}" { } (
                if failed k == [ ] then "touch $out" else "echo 'failed: ${toString (failed k)}'; exit 1"
              );
          in
          {
            inherit tests;
            checks.x86_64-linux = {
              examples = check "fast";
              examples-e2e = check "e2e";
            };
          };
      };
    };
  };
  yen.site.docs = { };
  yen.flake = { out, ... }: out;

  yen.section = {
    start = {
      title = "Start";
      order = 1;
    };
    migrate = {
      title = "Move to yen";
      order = 2;
    };
    concepts = {
      title = "Concepts";
      order = 3;
    };
    recipes = {
      title = "Recipes";
      order = 4;
    };
    nixos = {
      title = "NixOS patterns in yen";
      order = 5;
    };
    den = {
      title = "Den patterns in yen";
      order = 6;
    };
    batteries = {
      title = "Battery packs";
      order = 7;
    };
    query = {
      title = "Ask and prove";
      order = 8;
    };
    agents = {
      title = "For agents";
      order = 9;
    };
    perf = {
      title = "Performance";
      order = 10;
    };
    reference = {
      title = "Reference";
      order = 11;
    };
    project = {
      title = "Project";
      order = 12;
    };
  };
}
