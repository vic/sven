# The docs site as a yen fleet. The root `site` spawns one scope per page. Sections are data.
# Each page gives repo files (the .mdx), a sidebar entry, its template and its tests; the site reduces them to flake outputs.
{
  yen,
  lib,
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
      # the oracles, for github:denful/fastest: tests.fast.<page>.<check> and tests.e2e.<page>.<check> = { expr; expected; }
      tests = {
        reduce = merge;
        out =
          { tests, ... }:
          {
            tests = lib.genAttrs [ "fast" "e2e" ] (k: lib.mapAttrs (_: t: t.${k}) tests);
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
    model = {
      title = "Model";
      order = 3;
    };
    behavior = {
      title = "Behavior";
      order = 4;
    };
    principles = {
      title = "Principles";
      order = 5;
    };
    query = {
      title = "Ask and prove";
      order = 6;
    };
    agents = {
      title = "For agents";
      order = 7;
    };
    recipes = {
      title = "Recipes";
      order = 8;
    };
    nixos = {
      title = "NixOS patterns in yen";
      order = 9;
    };
    den = {
      title = "Den patterns in yen";
      order = 10;
    };
    batteries = {
      title = "Battery packs";
      order = 11;
    };
    perf = {
      title = "Performance";
      order = 12;
    };
    reference = {
      title = "Reference";
      order = 13;
    };
    project = {
      title = "Project";
      order = 14;
    };
  };
}
