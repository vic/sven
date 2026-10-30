# Fleet invariants: Datalog rules over the fleet's facts (`kind:K:ID`, `has:ASPECT:ID`, `edge:SINK:FROM:TO`,
# `error:CODE:FROM`). A true `bad:` atom is a violation, an undefined one an incomplete answer. An agent reads
# `check` (nix eval --file query.nix check) before and after a change; `stage` refuses a change that adds a violation.
{ yen, lib, ... }:
let
  machines = yen.lib.holds [
    yen.kinds.host
    yen.kinds.mac
    yen.kinds.guest
  ];
in
{
  yen.invariants = {
    # every machine has the base aspect (hostname, overlays)
    base =
      { scopes, ... }:
      map (s: {
        head = "bad:no-base:${s.id}";
        pos = [ "kind:${s.kind}:${s.id}" ];
        neg = [ "has:base:${s.id}" ];
      }) (lib.filter machines scopes);
    # every machine is reachable for management: it runs sshd through the clan sshd instance
    ssh =
      { scopes, ... }:
      map
        (s: {
          head = "bad:no-sshd:${s.id}";
          pos = [ "kind:${s.kind}:${s.id}" ];
          neg = [ "has:clan-sshd:${s.id}" ];
        })
        (
          lib.filter (
            s:
            yen.lib.holds [
              yen.kinds.host
              yen.kinds.mac
            ] s
            && !(lib.hasInfix "/host:lb/host:" s.id)
          ) scopes
        );
    # a host with a binary cache secret (attic) is never a mac: secrets stay on NixOS servers
    attic =
      { scopes, ... }:
      map (s: {
        head = "bad:attic-on-mac:${s.id}";
        pos = [ "has:attic:${s.id}" ];
      }) (lib.filter (s: yen.lib.holds yen.kinds.mac s) scopes);

    # ── between machines: what must hold across hosts, environments and services before anything deploys ──
    # a host's database host lives in the same environment (a prod app never writes to a staging database)
    db-same-env =
      { scopes, ... }:
      lib.concatMap
        (
          s:
          let
            x = lib.findFirst (h: yen.lib.holds yen.kinds.host h && h.name == s.dbOn.name) null scopes;
          in
          if x == null then
            [
              {
                head = "bad:db-dangling:${s.id}";
                pos = [ "kind:host:${s.id}" ];
              }
            ]
          else
            [
              {
                head = "bad:db-cross-env:${s.id}";
                pos = [ "ref:dbOn:${s.id}:host:${x.name}" ];
                neg = [ "ref:environment:${x.id}:environment:${s.environment.name}" ];
              }
            ]
        )
        (
          lib.filter (
            s:
            yen.lib.holds yen.kinds.host s && (s.dbOn or null) != null && !(lib.hasInfix "/host:lb/host:" s.id)
          ) scopes
        );
    # no two machines share an address (a variant such as lb-minimal is the same machine, so it is not counted)
    unique-addr =
      { scopes, ... }:
      let
        ms = lib.filter (
          s: machines s && (s.addr or null) != null && s.parent.kind or null != "host"
        ) scopes;
        byAddr = lib.groupBy (s: s.addr) ms;
      in
      lib.concatLists (
        lib.mapAttrsToList (
          a: ss:
          lib.optional (lib.length ss > 1) {
            head = "bad:addr-clash:${a}";
            pos = map (s: "val:addr:${s.id}:${a}") ss;
          }
        ) byAddr
      );
    # trust only flows down: a host never depends on a host in a less trusted environment (prod 3, lab 2, staging 1)
    trust-order =
      { scopes, ... }:
      let
        rank = {
          prod = 3;
          lab = 2;
          staging = 1;
        };
        hostScope = n: lib.findFirst (h: yen.lib.holds yen.kinds.host h && h.name == n) null scopes;
      in
      lib.concatMap (
        s:
        lib.concatMap (
          d:
          let
            x = hostScope d.name;
          in
          lib.optional (x != null && rank.${x.environment.name} < rank.${s.environment.name}) {
            head = "bad:trust-down:${s.id}:${x.name}";
            pos = [ "ref:dependsOn:${s.id}:host:${x.name}" ];
          }
        ) (s.dependsOn or [ ])
      ) (lib.filter (s: yen.lib.holds yen.kinds.host s) scopes);
  };
}
