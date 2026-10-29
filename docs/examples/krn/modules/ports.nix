# µKanren with finite domains: give each app a port in 8080..8083, all different, prometheus before grafana.
{ yen, lib, ... }:
let
  inherit (yen.lib.krn)
    run
    runAll
    freshNamed
    infd
    distinctfd
    ltfd
    eq
    label
    runFuel
    ;
  ports =
    apps: q:
    freshNamed apps (vs: [
      (infd (lib.attrValues vs) 8080 8083)
      (distinctfd (lib.attrValues vs))
      (ltfd vs.prometheus vs.grafana)
      (eq q vs)
      (label (lib.attrValues vs))
    ]);
  lb = yen.host.lb;
in
{
  yen.aspects.ports = {
    at = yen.kinds.fleet;
    out.ports = {
      first = run 1 (ports lb.apps); # one answer
      count = lib.length (runAll (ports lb.apps)); # every answer
      # the same relation, run backward: which app can take 8080?
      on8080 = lib.unique (
        lib.concatMap (a: lib.attrNames (lib.filterAttrs (_: p: p == 8080) a)) (runAll (ports lb.apps))
      );
      # a bounded search: `complete = false` means "stopped", never "no answer"
      bounded = removeAttrs (runFuel 1 5 (ports lb.apps)) [ "answers" ];
    };
    errors = lib.optional (run 1 (ports lb.apps) == [ ]) "ports: no assignment for lb";
  };
}
