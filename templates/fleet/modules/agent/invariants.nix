# Fleet invariants: Datalog rules, as data, over the fleet's typed facts (`[ "kind" K ID ]`, `[ "instance" ID KIND NAME ]`,
# `[ "parent" ID PARENT ]`, `[ "has" ASPECT ID ]`, `[ "ref" FIELD ID KIND NAME ]`, `[ "val" FIELD ID VALUE ]`). A variable
# is { var = "X"; }. A true `[ "bad" … ]` atom is a violation, an undefined one an incomplete answer. An agent reads
# `check` (nix eval --file query.nix check) before and after a change; `stage` refuses a change that adds a violation.
{ ... }:
let
  v = x: { var = x; };
  H = v "H";
  rule = head: pos: neg: { inherit head pos neg; };
  # the relations these rules derive
  machine = [
    "machine"
    H
  ];
  nested = [
    "nested"
    H
  ];
  env = id: e: [
    "ref"
    "environment"
    id
    "environment"
    e
  ];
in
{
  yen.relations = {
    machine.arity = 1; # a host, a mac or a guest
    nested.arity = 1; # a scope under a host (a variant such as lb-minimal, or a guest)
    hostNamed.arity = 1; # some host scope has this name
    rank.arity = 2; # an environment's trust: prod 3, lab 2, staging 1
  };
  yen.invariants = {
    # the vocabulary: machines, nested scopes, host names, trust ranks
    vocabulary =
      map
        (
          k:
          rule machine
            [
              [
                "kind"
                k
                H
              ]
            ]
            [ ]
        )
        [
          "host"
          "mac"
          "guest"
        ]
      ++ [
        (rule nested
          [
            [
              "parent"
              H
              (v "P")
            ]
            [
              "kind"
              "host"
              (v "P")
            ]
          ]
          [ ]
        )
        (rule
          [
            "hostNamed"
            (v "N")
          ]
          [
            [
              "instance"
              H
              "host"
              (v "N")
            ]
          ]
          [ ]
        )
      ]
      ++
        map
          (e: {
            head = [
              "rank"
              e.name
              e.rank
            ];
          })
          [
            {
              name = "prod";
              rank = 3;
            }
            {
              name = "lab";
              rank = 2;
            }
            {
              name = "staging";
              rank = 1;
            }
          ];
    # every machine has the base aspect (hostname, overlays)
    base = [
      (rule
        [
          "bad"
          "no-base"
          H
        ]
        [ machine ]
        [
          [
            "has"
            "base"
            H
          ]
        ]
      )
    ];
    # every host and mac (not a variant) is reachable for management: it runs sshd through the clan sshd instance
    ssh =
      map
        (
          k:
          rule
            [
              "bad"
              "no-sshd"
              H
            ]
            [
              [
                "kind"
                k
                H
              ]
            ]
            [
              nested
              [
                "has"
                "clan-sshd"
                H
              ]
            ]
        )
        [
          "host"
          "mac"
        ];
    # a host with a binary cache secret (attic) is never a mac: secrets stay on NixOS servers
    attic = [
      (rule
        [
          "bad"
          "attic-on-mac"
          H
        ]
        [
          [
            "kind"
            "mac"
            H
          ]
          [
            "has"
            "attic"
            H
          ]
        ]
        [ ]
      )
    ];

    # ── between machines: what must hold across hosts, environments and services before anything deploys ──
    # a host's database host exists, and lives in the same environment (a prod app never writes to a staging database)
    db-same-env =
      let
        dbOn = [
          "ref"
          "dbOn"
          H
          "host"
          (v "N")
        ];
      in
      [
        (rule
          [
            "bad"
            "db-dangling"
            H
          ]
          [ dbOn ]
          [
            nested
            [
              "hostNamed"
              (v "N")
            ]
          ]
        )
        (rule
          [
            "bad"
            "db-cross-env"
            H
          ]
          [
            dbOn
            [
              "instance"
              (v "D")
              "host"
              (v "N")
            ]
            (env H (v "E"))
          ]
          [
            nested
            (env (v "D") (v "E"))
          ]
        )
      ];
    # no two machines share an address (a variant or a guest under a host is not counted)
    unique-addr = [
      (rule
        [
          "bad"
          "addr-clash"
          (v "X")
        ]
        [
          [
            "machine"
            (v "A")
          ]
          [
            "machine"
            (v "B")
          ]
          [
            "val"
            "addr"
            (v "A")
            (v "X")
          ]
          [
            "val"
            "addr"
            (v "B")
            (v "X")
          ]
          [
            "lt"
            (v "A")
            (v "B")
          ]
        ]
        [
          [
            "nested"
            (v "A")
          ]
          [
            "nested"
            (v "B")
          ]
        ]
      )
    ];
    # trust only flows down: a host never depends on a host in a less trusted environment
    trust-order = [
      (rule
        [
          "bad"
          "trust-down"
          H
          (v "N")
        ]
        [
          [
            "kind"
            "host"
            H
          ]
          [
            "ref"
            "dependsOn"
            H
            "host"
            (v "N")
          ]
          [
            "instance"
            (v "X")
            "host"
            (v "N")
          ]
          (env H (v "EH"))
          (env (v "X") (v "EX"))
          [
            "rank"
            (v "EH")
            (v "RH")
          ]
          [
            "rank"
            (v "EX")
            (v "RX")
          ]
          [
            "lt"
            (v "RX")
            (v "RH")
          ]
        ]
        [ ]
      )
    ];
  };
}
