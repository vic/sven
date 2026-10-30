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
    # any table: the hosts and their environment
    out.hosts = docs.table [ "Host" "Environment" ] (
      map (h: [
        h
        yen.host.${h}.environment.name
      ]) (builtins.attrNames yen.host)
    );
    # flake templates from the directories under templates/ that have a flake.nix
    out.templates = builtins.mapAttrs (_: t: t.description) (
      docs.templates {
        root = ../templates;
        description = d: (import (d + "/flake.nix")).description;
      }
    );
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
