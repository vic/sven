# den-hoag relations + query calculus: a relation is a ref field; queries are yen.lib.graphs over it.
# `deployWaves`: a host deploys after what it depends on (layers). `dependents`: the reverse read (transpose).
# `impact`: everything that breaks, transitively, when a host goes down (reachers). A dependency cycle is an error.
{ yen, lib, ... }:
let
  G = yen.lib.graphs;
  all.instances = yen.kinds.host; # a tree request: every host, with its data
  dependsOn =
    hs:
    lib.listToAttrs (
      map (h: lib.nameValuePair h.name (map (d: d.name) h.dependsOn)) (lib.filter (h: h ? addr) hs)
    );
in
{
  yen.kinds.machine.fields.dependsOn = yen.lib.opt (yen.helpers.listOf yen.kinds.host) [ ];
  yen.host.web-1.dependsOn = [ yen.host.lb ];
  yen.host.web-2.dependsOn = [ yen.host.lb ];
  yen.host.stage.dependsOn = [ yen.host.web-1 ];
  yen.aspects.deploy-waves = {
    at = yen.fleet.main;
    cycle =
      { tree, ... }:
      let
        deps = dependsOn (lib.head (tree.select all));
      in
      {
        tree = [ all ];
        out = {
          deployWaves = G.layers deps;
          dependents = G.transpose deps;
          impact = lib.genAttrs (lib.attrNames deps) (G.reachers deps);
        };
        errors = [
          (map (c: "deploy: hosts depend on each other in a cycle: ${lib.concatStringsSep " -> " c}") (
            G.sccs deps
          ))
        ]; # one element: the list, as before
      };
  };
}
