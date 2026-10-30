# `succ` is an attrset from a node to its successors. Here: a host to the hosts it depends on.
{ yen, lib, ... }:
let
  G = yen.lib.graphs;
  hosts.instances = yen.kinds.host; # a tree request: every host, with its data
in
{
  yen.aspects.deploy-plan = {
    at = yen.kinds.fleet;
    cycle =
      { tree, ... }:
      let
        dependsOn = lib.listToAttrs (
          map (h: lib.nameValuePair h.name (map (d: d.name) h.dependsOn)) (lib.head (tree.select hosts))
        );
      in
      {
        tree = [ hosts ];
        out = [
          {
            deploy = {
              waves = G.layers dependsOn; # dependencies first: each wave after the waves it depends on
              impact = lib.genAttrs (lib.attrNames dependsOn) (G.reachers dependsOn); # who breaks if this host is down
              path = G.shortest dependsOn "lb" "db";
            };
          }
        ];
        errors = [
          (map (c: "deploy: a dependency cycle: ${lib.concatStringsSep " -> " c}") (
            lib.filter (c: lib.length c > 1) (G.sccs dependsOn)
          ))
        ]; # one element: the list, as before
      };
  };
}
