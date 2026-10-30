# Scale probe: N modules. Each module declares one aspect; aspects target hosts by a field and give two sinks.
# 1 fleet, 10 environments, N/10 hosts, 2 users per host. Run:
#   nix-instantiate --eval --strict bench/scale.nix --arg n 1000 -A probe
{
  n ? 100,
  hostCount ? null,
  perHost ? 4,
}:
let
  b = builtins;
  yen = (import ../default.nix).lib;
  hosts = if hostCount == null then n / 10 else hostCount;
  base =
    { yen, ... }:
    {
      yen.kinds.fleet = {
        spawns.env = _: yen.env;
        sinks.out.reduce = yen.lib.reduce.merge;
      };
      yen.kinds.env.spawns.host =
        s:
        b.listToAttrs (
          b.filter (x: x.value.env == s.name) (
            b.attrValues (
              b.mapAttrs (k: v: {
                name = k;
                value = v;
              }) yen.host
            )
          )
        );
      yen.kinds.host = {
        fields = {
          env = yen.lib.is b.isString;
          tier = yen.lib.is b.isInt;
        };
        spawns.user = _: {
          u1 = { };
          u2 = { };
        };
        sinks = {
          nixos = { };
          persist.reduce = yen.lib.reduce.set;
        };
      };
      yen.kinds.user = { };
      yen.fleet.main = { };
      yen.env = b.listToAttrs (
        b.genList (i: {
          name = "e${toString i}";
          value = { };
        }) 10
      );
      yen.host = b.listToAttrs (
        b.genList (i: {
          name = "h${toString i}";
          value = {
            env = "e${toString (i - i / 10 * 10)}";
            tier = i - i / 7 * 7;
          };
        }) hosts
      );
    };
  aspect =
    i:
    { yen, ... }:
    {
      yen.aspects."a${toString i}" = {
        at = s: s.kind == "host" && s.tier == i - i / 7 * 7;
        nixos =
          { host, ... }:
          {
            environment.etc."a${toString i}".text = host.name;
          };
        persist = "/var/lib/a${toString (i - i / 50 * 50)}";
      };
    };
  r = yen.eval { imports = [ base ] ++ b.genList aspect n; };
  # services: `perHost` per host, each on a port, each using the next service of its host as its database. Three
  # rules across machines (data, with variables): no port clash on a host, a database in the same environment, every
  # service monitored. The fleet is clean: the check must prove every absence.
  v = x: { var = x; };
  services =
    { yen, ... }:
    {
      yen.kinds.host.spawns.svc =
        s:
        b.listToAttrs (
          b.filter (x: x.value.host == s.name) (
            b.attrValues (
              b.mapAttrs (k: v: {
                name = k;
                value = v;
              }) yen.svc
            )
          )
        );
      yen.kinds.svc.fields = {
        host = yen.lib.is b.isString;
        port = yen.lib.is b.isInt;
        db = yen.lib.maybe yen.kinds.svc;
      };
      yen.svc = b.listToAttrs (
        b.concatLists (
          b.genList (
            h:
            b.genList (j: {
              name = "s${toString h}-${toString j}";
              value = {
                host = "h${toString h}";
                port = 8000 + j;
                db = if j + 1 < perHost then yen.svc."s${toString h}-${toString (j + 1)}" else null;
              };
            }) perHost
          ) hosts
        )
      );
      yen.aspects.monitor.at = yen.kinds.svc;
      yen.invariants.services = rules;
    };
  rules = [
    {
      head = [
        "bad"
        "port-clash"
        (v "A")
        (v "B")
      ];
      pos = [
        [
          "parent"
          (v "A")
          (v "H")
        ]
        [
          "parent"
          (v "B")
          (v "H")
        ]
        [
          "val"
          "port"
          (v "A")
          (v "P")
        ]
        [
          "val"
          "port"
          (v "B")
          (v "P")
        ]
        [
          "lt"
          (v "A")
          (v "B")
        ]
      ];
    }
    {
      head = [
        "bad"
        "db-cross-env"
        (v "S")
      ];
      pos = [
        [
          "ref"
          "db"
          (v "S")
          "svc"
          (v "N")
        ]
        [
          "instance"
          (v "D")
          "svc"
          (v "N")
        ]
        [
          "parent"
          (v "S")
          (v "H")
        ]
        [
          "parent"
          (v "H")
          (v "E")
        ]
        [
          "parent"
          (v "D")
          (v "H2")
        ]
      ];
      neg = [
        [
          "parent"
          (v "H2")
          (v "E")
        ]
      ];
    }
    {
      head = [
        "bad"
        "unmonitored"
        (v "S")
      ];
      pos = [
        [
          "kind"
          "svc"
          (v "S")
        ]
      ];
      neg = [
        [
          "has"
          "monitor"
          (v "S")
        ]
      ];
    }
  ];
  fleet = yen.eval {
    imports = [
      base
      services
    ]
    ++ b.genList aspect n;
  };
in
{
  inherit r fleet rules;
  # the scale oracle (.35): every rule proved over hundreds of services, with its certificate
  check = {
    services = b.length (b.filter (s: s.kind == "svc") fleet.scopes);
    inherit (fleet.check) ok certified;
    errors = b.length fleet.errors;
  };
  probe = {
    scopes = b.length r.scopes;
    errors = b.length r.errors;
    nixosElems = b.foldl' (a: x: a + b.length x) 0 (b.attrValues r.reduced.nixos);
    persist = b.length (r.reduced.persist."fleet:main/env:e0/host:h0");
  };
}
