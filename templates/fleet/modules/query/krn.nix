# Configuration synthesis with krn (µKanren with =/= and finite domains). The fleet states constraints; krn finds
# values that satisfy them, or none, which is an error record.
# 1. Ports: each app on a host gets a port from the host's range, no two apps share one (`distinctfd`), and an app
#    may ask to come before another (`ltfd`). Run backward, the same relation answers "which apps can take 8081".
# 2. Memory: a host's guests share its memory; each guest asks for a range; the host keeps a reserve (`plusfd`).
# 3. Placement: each host gets the database hosts of its own environment, a join over host records by unification.
{ yen, lib, ... }:
let
  K = yen.lib.krn;
  inherit (K)
    run
    runAll
    fresh
    freshNamed
    eq
    facto
    infd
    distinctfd
    ltfd
    plusfd
    lefd
    label
    ;
  lo = r: lib.head r;
  hi = r: lib.last r;
  portsRel =
    h: q:
    freshNamed h.apps (
      vs:
      [
        (infd (lib.attrValues vs) (lo h.portRange) (hi h.portRange))
        (distinctfd (lib.attrValues vs))
      ]
      ++ lib.mapAttrsToList (a: c: ltfd vs.${a} vs.${c}) (lib.filterAttrs (a: _: vs ? ${a}) h.portBefore)
      ++ [
        (eq q vs)
        (label (lib.attrValues vs))
      ]
    );
  # guest memory in GiB: each guest in its range, the running sums s1 … sk, and sk + the host's reserve within its ram
  # tree requests: every guest and host, with their data
  guestsReq.instances = yen.kinds.guest;
  hostsReq.instances = yen.kinds.host;
  byName = xs: lib.listToAttrs (map (x: lib.nameValuePair x.name x) xs);
  guestsOf =
    guests: h: lib.attrNames (lib.filterAttrs (_: g: g.on.name == h.name && g.ramRange != [ ]) guests);
  memRel =
    guests: h: q:
    let
      gs = guestsOf guests h;
      n = lib.length gs;
      sums = lib.genList (i: "__s${toString i}") n;
      v = vs: i: vs.${lib.elemAt sums i};
    in
    freshNamed (gs ++ sums) (
      vs:
      map (g: infd [ vs.${g} ] (lo guests.${g}.ramRange) (hi guests.${g}.ramRange)) gs
      ++ map (s: infd [ vs.${s} ] 0 h.ram) sums
      ++ lib.genList (i: plusfd (if i == 0 then 0 else v vs (i - 1)) vs.${lib.elemAt gs i} (v vs i)) n
      ++ lib.optional (n > 0) (lefd (v vs (n - 1)) (h.ram - h.ramReserve))
      ++ [
        (eq q (lib.getAttrs gs vs))
        (label (map (g: vs.${g}) gs))
      ]
    );
  # the allocation that gives the guests the most memory (the first, in label order, among the largest)
  # the allocation that gives the guests the most memory, by krn maximize within a fuel budget: a search cut by fuel is an
  # error record, never a silent "best"
  memSearch =
    guests: h:
    K.maximize h.ramFuel (m: lib.foldl' (a: x: a + x) 0 (lib.attrValues m)) (memRel guests h);
  bestMem =
    guests: h:
    let
      s = memSearch guests h;
    in
    if s.complete then s.best else null;
  hostRows =
    hosts:
    map (h: {
      inherit (h) name;
      env = h.environment.name;
      db = h.dbRole;
    }) (lib.filter (h: h ? addr) hosts);
in
{
  yen.kinds.machine.fields = {
    apps = yen.lib.opt (yen.helpers.listOf lib.types.str) [ ];
    portRange = yen.lib.opt (yen.helpers.listOf lib.types.int) [ ];
    portBefore = yen.lib.opt (yen.lib.is lib.isAttrs) { };
    dbRole = yen.lib.opt lib.types.bool false;
    ram = yen.lib.opt lib.types.int 0;
    ramReserve = yen.lib.opt lib.types.int 0;
    ramRange = yen.lib.opt (yen.helpers.listOf lib.types.int) [ ];
    ramFuel = yen.lib.opt lib.types.int 100000; # krn search steps for the memory allocation
  };
  yen.host.lb = {
    apps = [
      "grafana"
      "loki"
      "prometheus"
    ];
    portRange = [
      8080
      8083
    ];
    portBefore.prometheus = "grafana";
    dbRole = true;
  };
  yen.host.stage = {
    dbRole = true;
    ram = 16;
    ramReserve = 6;
  };
  yen.guest.ci.ramRange = [
    2
    8
  ];

  yen.aspects.memory-synthesis = {
    at = yen.lib.all [
      yen.kinds.host
      (s: guestsOf yen.guest s != [ ])
    ];
    cycle =
      { tree, scope, ... }:
      let
        host = scope;
        guests = byName (lib.head (tree.select guestsReq));
        s = memSearch guests host;
        m = bestMem guests host;
      in
      {
        tree = [ guestsReq ];
        nixos = lib.optionalAttrs (m != null) { environment.etc."guests/memory".text = builtins.toJSON m; };
        errors = [
          (
            lib.optional (s.complete && s.best == null)
              "memory: the guests of ${host.name} do not fit in ${toString host.ram} GiB with ${toString host.ramReserve} reserved"
            ++ lib.optional (
              !s.complete
            ) "memory: the search for ${host.name} ran out of fuel after ${toString s.count} answers"
          )
        ];
      };
  };

  yen.aspects.port-synthesis = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.apps != [ ])
    ];
    nixos =
      { host, ... }:
      let
        a = run 1 (portsRel host);
      in
      lib.optionalAttrs (a != [ ]) { environment.etc."apps/ports".text = builtins.toJSON (lib.head a); };
    errors =
      { host, ... }:
      lib.optional (run 1 (portsRel host) == [ ])
        "ports: no allocation for ${host.name}: ${toString (lib.length host.apps)} apps, ports ${toString host.portRange}";
  };
  yen.aspects.db-placement = {
    at = yen.fleet.main;
    cycle =
      { tree, ... }:
      let
        hosts = lib.head (tree.select hostsReq);
        rows = hostRows hosts;
      in
      {
        tree = [ hostsReq ];
        out = {
          dbPlacement = lib.genAttrs (map (r: r.name) rows) (
            h:
            runAll (
              q:
              fresh (
                {
                  env,
                  d,
                  own,
                }:
                [
                  (facto rows {
                    name = h;
                    inherit env;
                    db = own;
                  })
                  (facto rows {
                    name = d;
                    inherit env;
                    db = true;
                  })
                  (eq q d)
                ]
              )
            )
          );
          # backward: which apps can take port 8081 in some allocation of lb
          takes8081 = lib.unique (
            lib.concatMap (m: lib.attrNames (lib.filterAttrs (_: p: p == 8081) m)) (
              runAll (portsRel (lib.findFirst (yen.lib.same yen.host.lb) null hosts))
            )
          );
        };
      };
  };
}
