# `succ` is an attrset from a node to its successors. Here: a host to the hosts it depends on.
{ yen, lib, ... }:
let
  G = yen.lib.graphs;
  dependsOn = lib.mapAttrs (_: h: map (d: d.name) h.dependsOn) yen.host;
in
{
  yen.aspects.deploy-plan = {
    at = yen.kinds.fleet;
    out.deploy = {
      waves = G.layers dependsOn; # dependencies first: each wave after the waves it depends on
      impact = lib.genAttrs (lib.attrNames yen.host) (G.reachers dependsOn); # who breaks if this host is down
      path = G.shortest dependsOn "lb" "db";
    };
    errors = map (c: "deploy: a dependency cycle: ${lib.concatStringsSep " -> " c}") (
      lib.filter (c: lib.length c > 1) (G.sccs dependsOn)
    );
  };
}
