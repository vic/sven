# den-hoag relations + query calculus: a relation is a ref field; queries are yen.lib.graphs over it.
# `deployWaves`: a host deploys after what it depends on (layers). `dependents`: the reverse read (transpose).
# `impact`: everything that breaks, transitively, when a host goes down (reachers). A dependency cycle is an error.
{ yen, lib, ... }:
let
  G = yen.lib.graphs;
  hosts = lib.filterAttrs (_: h: h ? addr) yen.host;
  dependsOn = lib.mapAttrs (_: h: map (d: d.name) (h.dependsOn or [ ])) hosts;
in
{
  yen.kinds.machine.fields.dependsOn = yen.lib.opt (yen.helpers.listOf yen.kinds.host) [ ];
  yen.host.web-1.dependsOn = [ yen.host.lb ];
  yen.host.web-2.dependsOn = [ yen.host.lb ];
  yen.host.stage.dependsOn = [ yen.host.web-1 ];
  yen.aspects.deploy-waves = {
    at = yen.fleet.main;
    out =
      { ... }:
      {
        deployWaves = G.layers dependsOn;
        dependents = G.transpose dependsOn;
        impact = lib.genAttrs (lib.attrNames hosts) (G.reachers dependsOn);
      };
    errors =
      { ... }:
      map (c: "deploy: hosts depend on each other in a cycle: ${lib.concatStringsSep " -> " c}") (
        G.sccs dependsOn
      );
  };
}
