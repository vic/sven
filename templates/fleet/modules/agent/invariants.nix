# Fleet invariants: Datalog rules over the fleet's facts, by reference. A rule is a function of its variables; its
# literals come from `yen.facts` (fields, kind, has, instance, parent, lt) and `yen.relations`. A rule with `bad = H`
# that holds is a violation `[ "bad" <invariant> H ]`, an undefined one an incomplete answer. An agent reads
# `check` (nix eval --file query.nix check) before and after a change; `stage` refuses a change that adds a violation.
{ yen, ... }:
let
  inherit (yen.facts)
    machine
    kind
    has
    instance
    parent
    lt
    ;
  inherit (yen.relations)
    isMachine
    nested
    dbFound
    runsSshd
    rank
    ;
in
{
  yen.relations = {
    isMachine.arity = 1; # a host, a mac or a guest
    nested.arity = 1; # a scope under a host (a variant such as lb-minimal, or a guest)
    dbFound.arity = 1; # the host a machine uses as its database has a scope
    runsSshd.arity = 1; # a machine with a member of the sshd kit's server role
    rank.arity = 2; # an environment's trust: prod 3, lab 2, staging 1
  };
  yen.invariants = {
    # the vocabulary: machines, nested scopes, found databases, trust ranks
    vocabulary =
      map
        (
          k:
          { H }:
          {
            head = isMachine H;
            pos = [ (kind k H) ];
          }
        )
        [
          yen.kinds.host
          yen.kinds.mac
          yen.kinds.guest
        ]
      ++ [
        (
          { H, P }:
          {
            head = nested H;
            pos = [
              (parent H P)
              (kind yen.kinds.host P)
            ];
          }
        )
        (
          { H, M }:
          {
            head = runsSshd H;
            pos = [
              (parent M H)
              (has yen.aspects.kit-sshd-server M)
            ];
          }
        )
        (
          { H, D }:
          {
            head = dbFound H;
            pos = [ (machine.dbOn H D) ];
          }
        )
      ]
      ++
        map
          (
            e:
            { E }:
            {
              head = rank E e.rank;
              pos = [ (instance E e.env) ];
            }
          )
          [
            {
              env = yen.environment.prod;
              rank = 3;
            }
            {
              env = yen.environment.lab;
              rank = 2;
            }
            {
              env = yen.environment.staging;
              rank = 1;
            }
          ];
    # every machine has the base aspect (hostname, overlays)
    base =
      { H }:
      {
        bad = H;
        pos = [ (isMachine H) ];
        neg = [ (has yen.aspects.base H) ];
      };
    # every host and mac (not a variant) is reachable for management: it runs sshd through the sshd assembly
    ssh =
      map
        (
          k:
          { H }:
          {
            bad = H;
            pos = [ (kind k H) ];
            neg = [
              (nested H)
              (runsSshd H)
            ];
          }
        )
        [
          yen.kinds.host
          yen.kinds.mac
        ];
    # a host with a binary cache secret (attic) is never a mac: secrets stay on NixOS servers
    attic =
      { H }:
      {
        bad = H;
        pos = [
          (kind yen.kinds.mac H)
          (has yen.aspects.attic H)
        ];
      };

    # ── between machines: what must hold across hosts, environments and services before anything deploys ──
    # a host's database host exists
    db-exists =
      { H }:
      {
        bad = H;
        pos = [ (machine.dbOn.set H) ];
        neg = [
          (nested H)
          (dbFound H)
        ];
      };
    # a host's database lives in the same environment (a prod app never writes to a staging database)
    db-same-env =
      {
        H,
        D,
        E,
      }:
      {
        bad = H;
        pos = [
          (machine.dbOn H D)
          (machine.environment H E)
        ];
        neg = [
          (nested H)
          (machine.environment D E)
        ];
      };
    # no two machines share an address (a variant or a guest under a host is not counted)
    unique-addr =
      {
        A,
        B,
        X,
      }:
      {
        bad = X;
        pos = [
          (isMachine A)
          (isMachine B)
          (machine.addr A X)
          (machine.addr B X)
          (lt A B)
        ];
        neg = [
          (nested A)
          (nested B)
        ];
      };
    # trust only flows down: a host never depends on a host in a less trusted environment
    trust-order =
      {
        H,
        X,
        EH,
        EX,
        RH,
        RX,
      }:
      {
        bad = [
          H
          X
        ];
        pos = [
          (kind yen.kinds.host H)
          (machine.dependsOn H X)
          (machine.environment H EH)
          (machine.environment X EX)
          (rank EH RH)
          (rank EX RX)
          (lt RX RH)
        ];
      };
  };
}
