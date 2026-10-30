# µKanren with finite domains: give each app a port in 8080..8083, all different, prometheus before grafana.
{ yen, ... }:
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
    ;
  ports =
    apps: q:
    freshNamed apps (vs: [
      (infd (builtins.attrValues vs) 8080 8083)
      (distinctfd (builtins.attrValues vs))
      (ltfd vs.prometheus vs.grafana)
      (eq q vs)
      (label (builtins.attrValues vs))
    ]);
  lb.scopesOf = yen.host.lb; # a tree request: lb, with its data
in
{
  yen.kinds.world.spawns.host = _: yen.host;
  yen.kinds.host.fields.apps = yen.lib.is (v: builtins.isList v && builtins.all builtins.isString v);
  yen.host.lb.apps = [
    "grafana"
    "loki"
    "prometheus"
  ];

  yen.aspects.ports = {
    at = yen.kinds.world;
    cycle =
      { tree, ... }:
      let
        apps = (builtins.head (builtins.head (tree.select lb))).apps;
      in
      {
        tree = [ lb ];
        greetings = [
          {
            ports = {
              first = run 1 (ports apps); # one answer
              count = builtins.length (runAll (ports apps)); # every answer
            };
          }
        ];
      };
  };
}
