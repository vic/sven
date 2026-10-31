# den-hoag relations + query calculus: a relation is a ref field; queries are yen.lib.graphs over it (`G.of`, by ref).
# `deployWaves`: a host deploys after what it depends on (layers). `dependents`: the hosts that depend on each host.
# `impact`: everything that breaks, transitively, when a host goes down (reachers). A dependency cycle is an error.
{ yen, lib, ... }:
let
  G = yen.lib.graphs;
  all.instances = yen.kinds.host; # a tree request: every host, with its data
  names = map (h: h.name);
  byName = hs: f: lib.listToAttrs (map (h: lib.nameValuePair h.name (names (f h))) hs);
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
        hs = lib.filter (h: h ? addr) (lib.head (tree.select all));
        g = G.of hs (h: h.dependsOn);
      in
      {
        tree = [ all ];
        out = {
          deployWaves = map names (G.layers g);
          dependents = byName hs (h: lib.filter (x: lib.any (yen.lib.same h) x.dependsOn) hs);
          impact = byName hs (G.reachers g);
        };
        errors = [
          (map (
            c: "deploy: hosts depend on each other in a cycle: ${lib.concatStringsSep " -> " (names c)}"
          ) (G.sccs g))
        ]; # one element: the list, as before
      };
  };
}
