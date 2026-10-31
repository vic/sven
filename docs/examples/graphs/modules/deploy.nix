# `G.of nodes next`: a graph over instances. Here: every host, and the hosts it depends on. Answers are refs.
{ yen, lib, ... }:
let
  G = yen.lib.graphs;
  all.instances = yen.kinds.host; # a tree request: every host, with its data
  names = map (h: h.name);
in
{
  yen.aspects.deploy-plan = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      let
        hosts = lib.head (tree.select all);
        g = G.of hosts (h: h.dependsOn);
      in
      {
        tree = [ all ];
        out = [
          {
            deploy = {
              waves = map names (G.layers g); # dependencies first: each wave after the waves it depends on
              impact = lib.listToAttrs (map (h: lib.nameValuePair h.name (names (G.reachers g h))) hosts); # who breaks if this host is down
              path = names (G.shortest g yen.host.lb yen.host.db);
            };
          }
        ];
        errors = [
          (map (c: "deploy: a dependency cycle: ${lib.concatStringsSep " -> " (names c)}") (
            lib.filter (c: lib.length c > 1) (G.sccs g)
          ))
        ]; # one element: the list, as before
      };
  };
}
