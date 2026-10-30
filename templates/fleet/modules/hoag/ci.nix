# den-hoag CI capabilities, each as plain data and plain Nix: merge strategies with provenance, setting refs,
# claim dedup, negation over claims, a composite claim split by a sink stage, a demand cascade as spawns,
# a shadowing query, and a suppression chain as `at` predicates.
{ yen, lib, ... }:
let
  inherit (yen.lib)
    all
    not
    same
    opt
    ;
  inherit (yen.lib.reduce) entries;
  hosts = lib.filterAttrs (_: h: h ? addr) yen.host; # spawns read data
  allHosts.instances = yen.kinds.host; # a tree request: every host, with its data
  addressed = xs: lib.listToAttrs (map (h: lib.nameValuePair h.name h) (lib.filter (h: h ? addr) xs));

  # a discipline is a reduce: per key, the first layer that names a strategy decides it ("replace" when none);
  # a value { ref = k; } reads the final value of key k. Provenance lists every layer that set the key.
  strategies =
    es:
    let
      sorted = lib.sort (a: b: a.value.rank < b.value.rank) es;
      keys = lib.unique (lib.concatMap (e: lib.attrNames e.value.set) sorted);
      layersOf = k: lib.filter (e: e.value.set ? ${k}) sorted;
      strategy =
        k: lib.findFirst (s: s != null) "replace" (map (e: e.value.strategy.${k} or null) sorted);
      raw = lib.genAttrs keys (
        k:
        if strategy k == "append" then
          lib.concatMap (e: e.value.set.${k}) (layersOf k)
        else
          (lib.last (layersOf k)).value.set.${k}
      );
    in
    {
      value = {
        value = lib.mapAttrs (_: v: if lib.isAttrs v && v ? ref then raw.${v.ref} else v) raw;
        provenance = lib.genAttrs keys (
          k:
          map (e: {
            from = e.from.id;
            inherit (e.value) rank;
          }) (layersOf k)
        );
      };
      errors = [ ];
    };

  # the nearest host along `via` that has a motd; equal distance: the first in `order`
  visible =
    hosts: order: start:
    let
      reach = builtins.genericClosure {
        startSet = [
          {
            key = start;
            d = 0;
          }
        ];
        operator =
          x:
          map (m: {
            key = m.name;
            d = x.d + 1;
          }) (hosts.${x.key}.via or [ ]);
      };
      found = lib.filter (x: hosts.${x.key}.motd != null) reach;
      rank = n: lib.lists.findFirstIndex (o: o == n) (lib.length order) order;
      best = lib.foldl' (
        a: x: if a == null || x.d < a.d || x.d == a.d && rank x.key < rank a.key then x else a
      ) null found;
    in
    if best == null then null else hosts.${best.key}.motd;
in
{
  # H18 + H19: strategies, provenance, ref
  yen.kinds.host.sinks.tuning.reduce = strategies;
  yen.aspects.tuning-base = {
    at = yen.kinds.host;
    tuning = {
      rank = 0;
      set = {
        ports = [ 22 ];
        color = "grey";
        accent.ref = "color";
      };
      strategy.ports = "append";
    };
  };
  yen.aspects.tuning-env = {
    at = all [
      yen.kinds.host
      (yen.lib.within yen.environment.prod)
    ];
    tuning = {
      rank = 1;
      set.ports = [ 80 ];
    };
  };
  yen.aspects.tuning-lb = {
    at = yen.host.lb;
    tuning = {
      rank = 2;
      set = {
        ports = [ 443 ];
        color = "blue";
      };
    };
  };

  # H71: two claimants of one token give one node with sorted sharers
  yen.kinds.machine.fields.tokens = opt (yen.helpers.listOf lib.types.str) [ ];
  yen.host.web-2.tokens = [ "apitoken" ];
  yen.host.web-1.tokens = [
    "apitoken"
    "metrics"
  ];
  yen.kinds.fleet.sinks.token-claims.reduce = es: {
    value = lib.mapAttrs (_: xs: { sharers = lib.sort (a: b: a < b) (map (x: x.from.name) xs); }) (
      lib.groupBy (x: x.token) (
        lib.concatMap (
          e:
          map (t: {
            token = t;
            inherit (e) from;
          }) e.value
        ) es
      )
    );
    errors = [ ];
  };
  yen.aspects.token-claim = {
    at = all [
      yen.kinds.host
      (s: s.tokens != [ ])
    ];
    token-claims = { host, ... }: host.tokens;
  };

  # H72: lockdown keeps root claimants (nobody depends on them) and drops self-claims
  yen.aspects.db-lockdown = {
    at = all [
      yen.kinds.host
      (s: !s.minimal)
    ];
    cycle =
      {
        tree,
        scope,
        db-claims,
        ...
      }:
      let
        host = scope;
        hosts = addressed (lib.head (tree.select allHosts));
      in
      {
        tree = [ allHosts ];
        nixos = [
          {
            environment.etc."db/lockdown".text = toString (
              map (e: e.from.name) (
                lib.filter (
                  e:
                  same e.value.on host
                  && !same e.from host
                  && !lib.any (h: lib.any (same e.from) h.dependsOn) (lib.attrValues hosts)
                ) (lib.head db-claims)
              )
            );
          }
        ];
      };
  };

  # H73: a route claim is split into a secret claim and a connect claim by sink stages
  yen.kinds.fleet.sinks = {
    route-claims = {
      reduce = entries;
      secret-claims =
        { route-claims, ... }:
        lib.listToAttrs (map (e: lib.nameValuePair e.value { by = e.from.name; }) route-claims);
      connect-claims =
        { route-claims, ... }:
        lib.listToAttrs (map (e: lib.nameValuePair e.value { by = e.from.name; }) route-claims);
    };
    secret-claims.reduce = yen.lib.reduce.merge;
    connect-claims.reduce = yen.lib.reduce.merge;
  };
  yen.aspects.api-route = {
    at = yen.host.web-1;
    route-claims = "api";
  };

  # H74: a demand cascades into structure: one database per demand, each with a secret and a connect below it
  yen.kinds.machine.fields.demands = opt (yen.helpers.listOf lib.types.str) [ ];
  yen.host.web-1.demands = [
    "orders"
    "users"
  ];
  yen.host.web-2.demands = [
    "orders"
    "audit"
  ];
  yen.kinds.fleet.spawns.database =
    _:
    lib.genAttrs (lib.concatMap (h: h.demands) (lib.attrValues hosts)) (n: {
      by = map (h: h.name) (lib.filter (h: lib.elem n h.demands) (lib.attrValues hosts));
    });
  yen.kinds.database.spawns = {
    secret = s: { "${s.name}-pw" = { }; };
    connect = s: { "${s.name}-url" = { }; };
  };

  # H76: a query with shadowing: the nearer path wins, the label order breaks ties
  yen.kinds.machine.fields = {
    via = opt (yen.helpers.listOf yen.kinds.host) [ ];
    motd = yen.lib.maybe lib.types.str;
  };
  yen.host.stage.via = [
    yen.host.web-1
    yen.host.web-2
  ];
  yen.host.web-1 = {
    via = [ yen.host.lb ];
    motd = "w1";
  };
  yen.host.web-2.motd = "w2";
  yen.host.lb.motd = "lb";
  yen.aspects.visible-motd = {
    at = yen.fleet.main;
    cycle =
      { tree, ... }:
      let
        v = visible (addressed (lib.head (tree.select allHosts)));
      in
      {
        tree = [ allHosts ];
        out = [
          {
            visibleMotd = {
              a = v [ "lb" "web-1" "web-2" ] "stage";
              b = v [ "web-2" "web-1" ] "stage";
              w = v [ ] "web-1";
            };
          }
        ];
      };
  };

  # H99: suppression chain: a suppresses b, b suppresses c, c suppresses d
  yen.aspects.sup-a.at = yen.host.lb;
  yen.aspects.sup-b.at = all [
    yen.host.lb
    (not yen.aspects.sup-a)
  ];
  yen.aspects.sup-c.at = all [
    yen.host.lb
    (not yen.aspects.sup-b)
  ];
  yen.aspects.sup-d.at = all [
    yen.host.lb
    (not yen.aspects.sup-c)
  ];
}
