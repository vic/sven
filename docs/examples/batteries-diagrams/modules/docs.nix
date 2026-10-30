# Docs that follow the fleet: a kinds table, links to the line that defines a thing, a doc line for every kind.
{ yen, ... }:
let
  inherit (yen.lib.batteries) docs;
in
{
  yen.kinds.fleet.sinks.links = {
    reduce = docs.links { root = ./.; };
    out =
      { sinks, ... }:
      {
        links = sinks.links;
      };
  };
  yen.aspects.docs = {
    at = yen.fleet.main;
    links = {
      name = "db-field";
      file = "fleet.nix";
      needle = "db = maybe";
      text = "db";
    };
    out.kinds = docs.kinds yen.kinds yen.lib.graph;
    # a kind with no line here, or a line for a kind that is gone, is an error
    errors = docs.vocabulary {
      what = "kinds";
      names = builtins.attrNames yen.kinds;
      lines = {
        fleet = "the root";
        environment = "where hosts run";
        host = "a NixOS machine";
      };
    };
  };
}
