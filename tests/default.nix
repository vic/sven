# sven oracles. Run: nix-instantiate --eval --strict vic/tests -A failed   (expect [ ])
let
  sven = (import ../default.nix).lib;
  b = builtins;
  msgs = r: map (e: e.error) r.errors;
  has = r: m: b.elem m (msgs r);

  # the design §1 fleet; nixosSystem replaced by the module list
  fleet =
    extra:
    { sven, ... }:
    {
      sven.kinds.fleet = {
        spawns.host = _: sven.host;
        sinks.out.reduce = sven.lib.reduce.merge;
      };
      sven.kinds.host = {
        fields.addr = sven.lib.is b.isString;
        sinks.persist.reduce = sven.lib.reduce.set;
        sinks.nixos.out =
          { host, nixos, ... }:
          {
            nixosConfigurations.${host.name} = nixos;
          };
      };
      sven.fleet.main = { };
      sven.host.lb = extra;
      sven.aspects.motd = {
        at = sven.kinds.host;
        persist = "/var/lib/motd";
        nixos =
          { persist, ... }:
          {
            environment.etc.motd.text = b.concatStringsSep "\n" persist;
          };
      };
      sven.flake = { out, ... }: out;
    };
  good = sven.eval (fleet {
    addr = "10.0.1.1";
  });
  noAddr = sven.eval (fleet { });

  # §4: two feature files, types at two paths of one field; no merge
  settings = [
    (
      { sven, ... }:
      {
        sven.kinds.host.fields.settings.zfs.arcMax = sven.lib.maybe (sven.lib.is b.isInt);
      }
    )
    (
      { sven, ... }:
      {
        sven.kinds.host.fields.settings.k3s.role = sven.lib.opt (sven.lib.is b.isString) "agent";
      }
    )
  ];
  feat = data: sven.eval { imports = [ (fleet ({ addr = "a"; } // data)) ] ++ settings; };
  featLazy = sven.eval {
    imports = [
      (fleet { addr = "a"; })
      (
        { sven, ... }:
        {
          sven.kinds.host.fields.settings.lazy = sven.lib.opt (sven.lib.is b.isString) (throw "touched");
        }
      )
    ]
    ++ settings;
  };
  hostOf = r: b.head (b.filter (s: s.kind == "host") r.scopes);

  # §5: order is a sink; siblings by (order, key), parent first
  ordered =
    o:
    sven.eval (
      { sven, ... }:
      {
        sven.kinds.fleet.spawns.host = _: sven.host;
        sven.kinds.host = { };
        sven.fleet.main = { };
        sven.host = {
          a = { };
          b = { };
          c = { };
        };
        sven.aspects.c-first = {
          at = sven.host.c;
          order = o;
        };
      }
    );
  ids = r: map (s: s.id) r.scopes;

  # Q5: an arg nobody answers; the component may emit on `errors`
  q5 =
    arg:
    sven.eval (
      { sven, ... }:
      {
        imports = [ (fleet { addr = "a"; }) ];
        sven.kinds.cluster = { };
        sven.aspects.k3s = {
          at = sven.kinds.host;
          nixos = arg;
        };
        sven.aspects.warn = {
          at = sven.kinds.host;
          cycle =
            { tree, ... }:
            {
              tree = [
                {
                  category = "c";
                  nearest = sven.kinds.cluster;
                }
              ];
              errors = if tree.select "c" == [ ] then [ "no cluster: k3s off" ] else [ ];
            };
        };
      }
    );

  # imports nest; `_module.args` flow down to them
  argsDown = sven.eval {
    _module.args.greeting = "hi";
    imports = [
      {
        imports = [
          (
            { sven, greeting, ... }:
            {
              imports = [ (fleet { addr = greeting; }) ];
            }
          )
        ];
      }
    ];
  };
  argsMissing = sven.eval { imports = [ ({ nope, ... }: { }) ]; };

  # stack safety: a chain 3000 deep, a fan-out of 3000
  deep =
    n:
    sven.eval (
      { sven, ... }:
      {
        sven.kinds.node.spawns.node =
          s:
          let
            i = b.fromJSON (b.substring 5 9 s.key);
          in
          if i < n then { "${toString (i + 1)}" = { }; } else { };
        sven.kinds.top.spawns.node = _: { "0" = { }; };
        sven.top.t = { };
      }
    );
  wide =
    n:
    sven.eval (
      { sven, ... }:
      {
        sven.kinds.root.spawns.leaf =
          _:
          b.listToAttrs (
            b.genList (i: {
              name = toString i;
              value = { };
            }) n
          );
        sven.kinds.leaf = { };
        sven.root.r = { };
      }
    );

  # tree driver, positive: a node reads its nearest cluster
  treeHit = sven.eval (
    { sven, ... }:
    {
      sven.kinds.top.spawns.cluster = _: sven.cluster;
      sven.kinds.cluster.spawns.node = _: { n1 = { }; };
      sven.kinds.node.sinks.seen = { };
      sven.top.t = { };
      sven.cluster.c1 = { };
      sven.aspects.see = {
        at = sven.kinds.node;
        cycle =
          { tree, ... }:
          {
            tree = [
              {
                category = "c";
                nearest = sven.kinds.cluster;
              }
            ];
            seen = map (c: c.name) (tree.select "c");
          };
      };
    }
  );
  # structure from presence (Den #525): a child exists only where an aspect holds at its parent
  presence = sven.eval (
    { sven, ... }:
    {
      sven.kinds.top.spawns.host = _: sven.host;
      sven.kinds.host.spawns.svc =
        p: if sven.lib.holds sven.aspects.server p then { web = { }; } else { };
      sven.kinds.svc = { };
      sven.top.t = { };
      sven.host = {
        a = { };
        b = { };
      };
      sven.aspects.server.at = sven.host.a;
    }
  );
  # a function element that reads a sink: two givers whose sink values differ are two elements, not one
  sinkArgs = sven.eval (
    { sven, ... }:
    {
      sven.kinds.fleet = {
        spawns.environment = _: sven.environment;
        sinks.seen = { };
      };
      sven.kinds.environment = {
        spawns.host =
          s:
          b.listToAttrs (
            map (n: {
              name = n;
              value = sven.host.${n};
            }) (b.filter (n: sven.host.${n}.environment.name == s.name) (b.attrNames sven.host))
          );
        sinks.tag.reduce = sven.lib.reduce.one;
      };
      sven.kinds.host.fields.environment = sven.kinds.environment;
      sven.fleet.main = { };
      sven.environment = {
        prod = { };
        staging = { };
      };
      sven.host = {
        a.environment = sven.environment.prod;
        b.environment = sven.environment.staging;
        c.environment = sven.environment.prod;
      };
      sven.aspects.envtag = {
        at = sven.kinds.environment;
        tag = { environment, ... }: environment.name;
      };
      sven.aspects.report = {
        at = sven.kinds.host;
        seen = { tag, ... }: tag;
      };
    }
  );

  # Den CI gaps closed: derived defaults, bad `at`, one key from many files, static once per receiver
  gaps = sven.eval (
    { sven, ... }:
    {
      imports = [
        { sven.aspects.multi.nixos = { scope, ... }: [ "a-${scope.name}" ]; }
        { sven.aspects.multi.nixos = { scope, ... }: [ "b-${scope.name}" ]; }
      ];
      sven.kinds.fleet = {
        spawns.host = _: sven.host;
      };
      sven.kinds.host = {
        fields.vpn = sven.lib.derive (sven.lib.is b.isString) (self: "vpn-${self.name}");
        spawns.user = _: {
          u1 = { };
          u2 = { };
        };
        sinks.nixos = { };
      };
      sven.kinds.user = { };
      sven.fleet.main = { };
      sven.host = {
        h1 = { };
        h2.vpn = "custom";
      };
      sven.aspects.multi.at = sven.kinds.host;
      sven.aspects.shared = {
        at = [
          sven.kinds.host
          sven.kinds.user
        ];
        nixos = "marker";
      };
      sven.aspects.typo.at = "host";
    }
  );
  # aspect refs on cycles: three values (well-founded semantics)
  logic =
    cyclic:
    sven.eval (
      { sven, ... }:
      {
        sven.kinds.top.spawns.host = _: sven.host;
        sven.kinds.host.spawns.user = _: { u = { }; };
        sven.kinds.user = { };
        sven.top.t = { };
        sven.host.h = { };
        sven.aspects =
          let
            inherit (sven.lib)
              all
              not
              within
              has
              ;
          in
          {
            a.at = all [
              sven.kinds.host
              (not sven.aspects.b)
            ];
            b.at =
              if cyclic then
                all [
                  sven.kinds.host
                  (not sven.aspects.a)
                ]
              else
                sven.kinds.host;
            c.at = all [
              sven.kinds.host
              (not sven.aspects.a)
            ]; # reads an undefined: undefined too
            p.at = sven.aspects.q;
            q.at = sven.aspects.p; # a positive cycle: unfounded, false
            w.at = all [
              sven.kinds.user
              (within sven.aspects.b)
            ]; # within crosses scopes: no cycle
            v.at = all [
              sven.kinds.host
              (has sven.aspects.w)
            ];
          };
      }
    );
  diamond =
    k:
    sven.eval (
      { sven, ... }:
      {
        sven.kinds.top.spawns.host = _: sven.host;
        sven.kinds.host = { };
        sven.top.t = { };
        sven.host.h = { };
        sven.aspects = {
          x0.at = sven.kinds.host;
        }
        // b.listToAttrs (
          b.concatMap (
            i:
            let
              p = "x${toString (i - 1)}";
            in
            [
              {
                name = "l${toString i}";
                value.at = sven.aspects.${p};
              }
              {
                name = "r${toString i}";
                value.at = sven.aspects.${p};
              }
              {
                name = "x${toString i}";
                value.at = sven.lib.all [
                  sven.aspects."l${toString i}"
                  sven.aspects."r${toString i}"
                ];
              }
            ]
          ) (b.genList (i: i + 1) k)
        );
      }
    );

  G = sven.graphs;
  D = sven.datalog;
  K = sven.krn;
  ring = {
    a = [ "b" ];
    b = [ "c" ];
    c = [ "a" ];
    d = [ "a" ];
  };
  dag = {
    app = [
      "db"
      "cache"
    ];
    cache = [ "net" ];
    db = [ "net" ];
    net = [ ];
  };
  choice = [
    {
      head = "a";
      neg = [ "b" ];
    }
    {
      head = "b";
      neg = [ "a" ];
    }
    {
      head = "c";
      pos = [ "a" ];
    }
    { head = "s"; }
    {
      head = "t";
      pos = [ "u" ];
    }
  ];

  # agent surface fixtures
  portsBase =
    { sven, ... }:
    {
      sven.kinds.top.spawns.host = _: sven.host;
      sven.kinds.host = {
        fields.port = {
          check = p: b.isInt p && p < 65536;
          name = "Port";
        };
        sinks.fw = { };
      };
      sven.top.t = { };
      sven.host = {
        a.port = 22;
        b.port = 80;
      };
      sven.aspects.firewall = {
        at = sven.host.a;
        fw = "on";
      };
      sven.invariants.fw =
        { scopes, ... }:
        map (s: {
          head = "bad:no-firewall:${s.id}";
          pos = [ "kind:host:${s.id}" ];
          neg = [ "has:firewall:${s.id}" ];
        }) scopes;
    };
  ports =
    extra:
    sven.eval (
      { sven, ... }:
      {
        imports = [ extra ];
        sven.kinds.top.spawns.host = _: sven.host;
        sven.kinds.host = {
          fields.port = {
            check = p: b.isInt p && p < 65536;
            name = "Port";
          };
          sinks.fw = { };
        };
        sven.top.t = { };
        sven.host = {
          a.port = 22;
          b.port = 80;
        };
        sven.aspects.firewall = {
          at = sven.host.a;
          fw = "on";
        };
        sven.invariants.fw =
          { scopes, ... }:
          map (s: {
            head = "bad:no-firewall:${s.id}";
            pos = [ "kind:host:${s.id}" ];
            neg = [ "has:firewall:${s.id}" ];
          }) scopes;
      }
    );
  rec1 = r: code: b.head (b.filter (e: e.code == code) r.errors);

  checks = {
    errors-v2-check =
      let
        e = rec1 (ports { sven.host.c.port = 70000; }) "check";
      in
      e.want == "Port"
      && e.path == [ "port" ]
      && e.got == 70000
      && e.class == "fixable"
      && e.from == "host:c"
      && e.error == "port fails its check";
    errors-v2-near =
      (rec1 (ports { sven.host.b.prot = 1; }) "unknown-field").near == [ "port" ]
      && (rec1 (ports { sven.host.b.zzzzzz = 1; }) "unknown-field").near == [ ];
    errors-v2-two-answers =
      let
        e = rec1 (ports { sven.host.a.port = 23; }) "two-answers";
      in
      e.path == [
        "host"
        "a"
        "port"
      ]
      && e.got == 2;
    declared-in =
      let
        r = ports { sven.aspects.firewall.nixos = { }; };
      in
      b.length (
        r.declaredIn [
          "aspects"
          "firewall"
        ]
      ) == 2
      &&
        r.declaredIn [
          "aspects"
          "nope"
        ] == [ ];
    invariants-check =
      let
        r = ports { };
      in
      r.check.violations == [ "bad:no-firewall:top:t/host:b" ]
      && r.check.incomplete == [ ]
      && !r.check.ok
      && (ports (
        { sven, ... }:
        {
          sven.aspects.fw-b = {
            at = sven.host.b;
            fw = "on";
          };
          sven.aspects.firewall.at = sven.host.b;
        }
      )).check.ok;
    invariants-incomplete =
      let
        r = ports {
          sven.invariants.loop = [
            {
              head = "bad:loop";
              neg = [ "ok:loop" ];
            }
            {
              head = "ok:loop";
              neg = [ "bad:loop" ];
            }
          ];
        };
      in
      r.check.incomplete == [ "bad:loop" ] && !b.elem "bad:loop" r.check.violations && !r.check.ok;
    schema-exact =
      let
        s =
          (ports (
            { sven, ... }:
            {
              sven.kinds.host.sinks.tags.reduce = sven.lib.reduce.set;
            }
          )).schema;
      in
      s.kinds.host == {
        fields.port.type = "Port";
        spawns = [ ];
        instances = 2;
        scopes = 2;
        sinks = {
          fw = {
            reduce = "list";
            of = null;
            feeds = [ ];
            out = false;
            conditional = false;
          };
          tags = {
            reduce = "set";
            of = null;
            feeds = [ ];
            out = false;
            conditional = false;
          };
        };
      }
      && s.kinds.top.spawns == [ "host" ]
      &&
        s.aspects.firewall == {
          keys = [ "fw" ];
          cycle = false;
          files = [ "root" ];
          activeAt = 1;
        }
      && s.invariants == [ "fw" ]
      && b.isString (b.toJSON s);
    explain =
      let
        r = ports (
          { sven, ... }:
          {
            sven.aspects.both.at = sven.lib.all [
              sven.kinds.host
              (sven.lib.not sven.aspects.firewall)
            ];
          }
        );
        e = r.explain "both" "top:t/host:b" 3;
        all' = b.head e.at.kids;
      in
      e.active
      && all'.op == "all"
      &&
        map (k: k.op) all'.kids == [
          "kind"
          "not"
        ]
      && (b.head (b.elemAt all'.kids 1).kids).value == false
      && (b.head (r.explain "both" "top:t/host:a" 1).at.kids).kids == "cut"
      && (r.explain "bth" "top:t/host:a" 1).near == [ "both" ]
      && (r.explain "both" "top:t/host:z" 1).code == "unknown-scope"
      &&
        (r.explain "firewall" "top:t/host:a" 2).gives == [
          {
            sink = "fw";
            to = "top:t/host:a";
          }
        ];
    stage-ok-and-diff =
      let
        base = {
          imports = [ portsBase ];
        };
        s = sven.stage {
          inherit base;
          change = {
            sven = {
              host.c.port = 443;
              aspects.firewall.at = [
                {
                  kind = "host";
                  name = "c";
                }
              ];
            };
          };
        };
      in
      s.ok
      && s.diff.scopes.added == [ "top:t/host:c" ]
      && s.diff.scopes.removed == [ ]
      && b.isString s.sha
      && s.diff.active.added == [ "firewall@top:t/host:c" ]
      &&
        (sven.stage {
          inherit base;
          change = b.fromJSON s.render;
        }).diff == s.diff;
    stage-refuses =
      let
        base = {
          imports = [ portsBase ];
        };
        ch = sven.change.set [ "host" "a" "port" ] 23;
        s = sven.stage {
          inherit base;
          change = ch;
        };
      in
      !s.ok
      && b.any (e: e.code == "two-answers") s.errors
      &&
        (b.head
          (sven.stage {
            inherit base;
            change = ch;
            rejected = [ s.sha ];
          }).refused
        ).class == "authority"
      && (
        let
          v = sven.stage {
            inherit base;
            change = sven.change.set [ "host" "c" "port" ] 1;
          };
        in
        v.violations == [ "bad:no-firewall:top:t/host:c" ] && v.errors == [ ] && !v.ok
      );
    grants-narrow =
      let
        g = sven.grant {
          scopes = [ "top:t/host:a" ];
          sinks = [ "fw" ];
        };
        all' = sven.grant { scopes = [ "top:t" ]; };
        e = to: sink: { inherit to sink; };
      in
      sven.allowed g (e "top:t/host:a" "fw")
      && !sven.allowed g (e "top:t/host:b" "fw")
      && !sven.allowed g (e "top:t/host:a" "nixos")
      && sven.narrow all' g == g
      && sven.narrow g all' == g
      && (sven.narrow g (sven.grant { scopes = [ "top:t/host:b" ]; })).scopes == [ ]
      &&
        (sven.stage {
          base = {
            imports = [ portsBase ];
          };
          change = {
            sven.aspects.firewall.at = [
              {
                kind = "host";
                name = "b";
              }
            ];
          };
          grant = g;
        }).refused != [ ];
    agent-json =
      let
        a = sven.agent (ports {
          sven.host.c.port = 70000;
        });
      in
      b.fromJSON (b.toJSON a) == a
      && a.counts.scopes == 4
      && b.length a.errors == 1
      &&
        sven.jsonSafe {
          f = x: x;
          p = ./.;
        } == {
          f = "<function>";
          p = toString ./.;
        };
    agent-context =
      let
        r = ports (
          { sven, ... }:
          {
            sven.kinds.host.sinks.fw2 = { };
            sven.aspects.more = {
              at = sven.host.a;
              fw = "x";
              fw2 = "y";
            };
          }
        );
        c = r.context "top:t/host:a" { maxEdges = 1; };
      in
      c.received.truncated == {
        shown = 1;
        of = 3;
      }
      && b.length c.received.items == 1
      &&
        c.aspects.items == [
          "firewall"
          "more"
        ]
      && c.parent == "top:t"
      && (r.context "top:t/host:q" { }).code == "unknown-scope"
      && b.length (r.context "top:t/host:q" { }).near == 2
      && b.fromJSON (b.toJSON c) == c;
    stored-queries =
      let
        r = ports {
          sven.queries = {
            portOf = { host, r, ... }: (b.head (b.filter (s: s.name == host) r.scopes)).port;
            count =
              {
                kind ? "host",
                r,
              }:
              b.length (b.filter (s: s.kind == kind) r.scopes);
          };
        };
      in
      r.queries == {
        count = {
          required = [ ];
          optional = [ "kind" ];
        };
        portOf = {
          required = [ "host" ];
          optional = [ ];
        };
      }
      && r.ask "portOf" { host = "b"; } == 80
      && r.ask "count" { } == 2
      && r.ask "count" { kind = "top"; } == 1
      && (r.ask "portOf" { }).code == "missing-param"
      &&
        (r.ask "portOf" {
          host = "a";
          hots = 1;
        }).code == "unknown-param"
      && (r.ask "portof" { }).near == [ "portOf" ];
    history =
      let
        h = sven.history {
          url = "file://${toString ./..}";
          revs = [
            "33010b09579939ebe344cc23ab2f1b5650e295d1"
            "5fa598ac90c560306d9ddcc80d8647798578e7e0"
          ];
          module = "tests/fixtures/history.nix";
        };
      in
      (b.elemAt h 1).changes == [
        {
          path = [
            "host"
            "a"
            "port"
          ];
          old = 22;
          new = 2222;
        }
      ]
      && (b.elemAt h 0).changes == [ ]
      &&
        (sven.asOf {
          url = "file://${toString ./..}";
          rev = "33010b09579939ebe344cc23ab2f1b5650e295d1";
          module = "tests/fixtures/history.nix";
        }).data.host.a.port == 22;
    # reduce errors name their receiver and sink: a strategy cannot know them, the engine sets them
    reduce-error-receiver =
      let
        r = sven.eval (
          { sven, ... }:
          {
            sven.kinds.top = {
              spawns.h = _: sven.h;
            };
            sven.kinds.h.sinks.admin.reduce = sven.lib.reduce.one;
            sven.top.t = { };
            sven.h.a = { };
            sven.aspects.x = {
              at = sven.kinds.h;
              admin = "ana";
            };
            sven.aspects.y = {
              at = sven.kinds.h;
              admin = "bo";
            };
          }
        );
      in
      b.map (e: { inherit (e) code from sink; }) r.errors == [
        {
          code = "one";
          from = "top:t/h:a";
          sink = "admin";
        }
      ];
    # an aspect's `errors` key gives records too; `from` is always the giving scope
    aspect-error-record =
      let
        r = sven.eval (
          { sven, ... }:
          {
            sven.kinds.top = {
              spawns.h = _: sven.h;
            };
            sven.kinds.h = { };
            sven.top.t = { };
            sven.h.a = { };
            sven.aspects.x = {
              at = sven.kinds.h;
              errors = [
                {
                  code = "dup-addr";
                  error = "two hosts at 10.0.0.1";
                  fix = "change one";
                  from = "forged";
                }
                "plain message"
              ];
            };
          }
        );
      in
      b.map (e: {
        inherit (e)
          code
          error
          from
          class
          ;
      }) r.errors == [
        {
          code = "dup-addr";
          error = "two hosts at 10.0.0.1";
          from = "top:t/h:a";
          class = "fixable";
        }
        {
          code = "error";
          error = "plain message";
          from = "top:t/h:a";
          class = "fixable";
        }
      ]
      && (b.head r.errors).fix == "change one";
    # a declared bound that is null is open
    valid-at-null =
      sven.validAt "2026-11-15" {
        validFrom = null;
        validTo = null;
      }
      && sven.validAt "2026-11-15" {
        validFrom = "2026-01-01";
        validTo = null;
      }
      && !sven.validAt "2026-11-15" {
        validFrom = null;
        validTo = "2026-10-31";
      };
    valid-at =
      let
        r = sven.eval (
          { sven, ... }:
          {
            imports = [ ./fixtures/history.nix ];
            sven.aspects.backup.at = sven.lib.all [
              sven.kinds.host
              (sven.lib.validAt "2026-11-15")
            ];
            sven.aspects.late.at = sven.lib.all [
              sven.kinds.host
              (sven.lib.validAt "2027-01-01")
            ];
          }
        );
      in
      r.active.backup."top:t/host:a"
      && r.active.backup."top:t/host:b"
      && !r.active.late."top:t/host:a"
      && r.active.late."top:t/host:b";
    without =
      let
        w = sven.without {
          files = [
            ./fixtures/without/base.nix
            ./fixtures/without/db.nix
          ];
          path = [
            "host"
            "db"
          ];
        };
      in
      w.dropped == [ ./fixtures/without/db.nix ]
      && b.all (s: s.name != "db") w.r.scopes
      && b.any (s: s.name == "web") w.r.scopes
      &&
        (sven.without {
          files = [
            ./fixtures/without/base.nix
            ./fixtures/without/db.nix
          ];
          path = [
            "host"
            "nope"
          ];
        }).dropped == [ ];
    impact =
      let
        r = sven.eval {
          imports = [
            ./fixtures/without/base.nix
            ./fixtures/without/db.nix
          ];
        };
        i = r.impact "top:t/host:db" { };
      in
      i.reached == [
        {
          scope = "top:t";
          depth = 1;
          via = "peers";
        }
      ]
      &&
        i.truncated == {
          shown = 1;
          of = 1;
        }
      && (r.impact "top:t/host:db" { sinks = [ "nixos" ]; }).reached == [ ]
      && (r.impact "top:t/host:db" { sinks = [ "peer" ]; }).code == "unknown-sink"
      && (r.impact "top:t/host:dd" { }).code == "unknown-scope";
    labels-floor =
      let
        r = sven.eval {
          imports = [
            ./fixtures/labels/modules/base.nix
            ./fixtures/labels/agent/web.nix
          ];
        };
      in
      r.labels.web.trust == 1
      && r.labels.web.prefix == "agent/"
      && r.labels.cache.trust == 1
      && b.all (x: x.trust == 1 && b.match ".*agent/web.nix" x.file != null) (r.floor 3)
      && b.length (r.floor 3) >= 2
      && r.floor 1 == [ ]
      && (sven.eval { imports = [ ./fixtures/labels/modules/base.nix ]; }).labels.web.trust == 3;
    field-facts =
      let
        r = ports (
          { sven, ... }:
          {
            sven.kinds.host.fields.peer = sven.lib.maybe sven.kinds.host;
            sven.host.b.peer = sven.host.a;
          }
        );
      in
      b.elem "val:port:top:t/host:a:22" r.facts
      && b.elem "ref:peer:top:t/host:b:host:a" r.facts
      && !(b.elem "ref:peer:top:t/host:a:host:b" r.facts);
    check-whynot =
      let
        r = ports (
          { sven, ... }:
          {
            sven.aspects.fw-b = {
              at = sven.host.b;
              fw = "on";
            };
            sven.aspects.firewall.at = sven.host.b;
          }
        );
      in
      r.check.ok
      && b.any (x: x.blocking == [ "has:firewall:top:t/host:b" ]) (
        r.check.whyNot "bad:no-firewall:top:t/host:b"
      )
      && (r.check.proof "kind:host:top:t/host:a").atom == "kind:host:top:t/host:a"
      && (ports { }).check.whyNot "bad:no-firewall:top:t/host:b" == [ ];
    program-validate =
      let
        r = ports { };
        v = sven.program.validate r;
      in
      v [
        {
          op = "set";
          path = [
            "host"
            "c"
            "port"
          ];
          value = 443;
        }
        {
          op = "place";
          aspect = "firewall";
          kind = "host";
          name = "c";
        }
      ] == [ ]
      &&
        map (e: e.near or null) (v [
          {
            op = "set";
            path = [
              "hots"
              "c"
              "port"
            ];
            value = 1;
          }
        ]) == [ [ "host" ] ]
      &&
        map (e: e.near or null) (v [
          {
            op = "set";
            path = [
              "host"
              "c"
              "prot"
            ];
            value = 1;
          }
        ]) == [ [ "port" ] ]
      &&
        map (e: e.near or null) (v [
          {
            op = "place";
            aspect = "firewal";
            kind = "host";
            name = "c";
          }
        ]) == [ [ "firewall" ] ]
      && map (e: e.near or null) (v [ { op = "plac"; } ]) == [ [ "place" ] ]
      && b.length (v [ { } ]) == 1;
    program-dryrun =
      let
        base = {
          imports = [ portsBase ];
        };
        d =
          p:
          sven.program.dryRun {
            inherit base;
            prog = p;
          };
        ok = d [
          {
            op = "new";
            kind = "host";
            name = "c";
            fields.port = 443;
          }
          {
            op = "place";
            aspect = "firewall";
            kind = "host";
            name = "c";
          }
        ];
        bad = d [
          {
            op = "new";
            kind = "host";
            name = "c";
            fields.port = 443;
          }
        ];
      in
      ok.ok
      && ok.valid
      && ok.diff.scopes.added == [ "top:t/host:c" ]
      && b.isString ok.sha
      && !bad.ok
      && bad.violations == [ "bad:no-firewall:top:t/host:c" ]
      && !(d [
        {
          op = "set";
          path = [ "hots" ];
          value = 1;
        }
      ]).valid
      &&
        b.fromJSON (
          sven.program.render [
            {
              op = "set";
              path = [
                "host"
                "c"
                "port"
              ];
              value = 1;
            }
          ]
        ) == [
          {
            op = "set";
            path = [
              "host"
              "c"
              "port"
            ];
            value = 1;
          }
        ];
    invariants-why =
      (b.head ((ports { }).check.why "bad:no-firewall:top:t/host:b")).neg
      == [ "has:firewall:top:t/host:b" ];
    graphs-reach =
      G.reach dag "app" == [
        "cache"
        "db"
        "net"
      ]
      && G.reach dag "net" == [ ]
      &&
        G.reachers dag "net" == [
          "app"
          "cache"
          "db"
        ];
    graphs-topo =
      G.topo dag == {
        ok = true;
        order = [
          "net"
          "cache"
          "db"
          "app"
        ];
        stuck = [ ];
      }
      && (G.topo ring).ok == false
      &&
        (G.topo ring).stuck == [
          "a"
          "b"
          "c"
          "d"
        ];
    graphs-layers =
      G.layers dag == [
        [ "net" ]
        [
          "cache"
          "db"
        ]
        [ "app" ]
      ];
    graphs-cycles =
      G.cycles ring == [
        "a"
        "b"
        "c"
      ]
      && G.cycles dag == [ ]
      &&
        G.sccs ring == [
          [
            "a"
            "b"
            "c"
          ]
        ];
    graphs-paths =
      G.shortest ring "d" "c" == [
        "d"
        "a"
        "b"
        "c"
      ]
      && G.shortest dag "net" "app" == null
      &&
        G.paths dag "app" "net" == [
          [
            "app"
            "cache"
            "net"
          ]
          [
            "app"
            "db"
            "net"
          ]
        ];
    datalog-wfs =
      let
        w = D.wfs choice;
      in
      w.true == [ "s" ]
      &&
        w.undefined == [
          "a"
          "b"
          "c"
        ]
      &&
        w.false == [
          "t"
          "u"
        ];
    datalog-stratified =
      let
        w = D.wfs (choice ++ [ { head = "b"; } ]);
      in
      w.true == [
        "b"
        "s"
      ]
      && w.undefined == [ ]
      &&
        w.false == [
          "a"
          "c"
          "t"
          "u"
        ];
    datalog-stable =
      D.stable choice == [
        [
          "b"
          "s"
        ]
        [
          "a"
          "c"
          "s"
        ]
      ]
      &&
        D.stable [
          {
            head = "p";
            neg = [ "p" ];
          }
        ] == [ ];
    datalog-why =
      D.why choice (D.wfs choice) "s" == [ { head = "s"; } ] && D.why choice (D.wfs choice) "t" == [ ];
    krn-backward =
      map (map K.toList) (
        K.runAll (
          q:
          K.fresh (
            { a, b }:
            [
              (K.appendo a b (
                K.fromList [
                  1
                  2
                ]
              ))
              (K.eq q [
                a
                b
              ])
            ]
          )
        )
      ) == [
        [
          [ ]
          [
            1
            2
          ]
        ]
        [
          [ 1 ]
          [ 2 ]
        ]
        [
          [
            1
            2
          ]
          [ ]
        ]
      ]
      &&
        map K.toList (
          K.run 1 (
            q:
            K.appendo (K.fromList [ 1 ]) (K.fromList [
              2
              3
            ]) q
          )
        ) == [
          [
            1
            2
            3
          ]
        ];
    krn-unify-records =
      K.runAll (
        q:
        K.fresh (
          { x }:
          [
            (K.eq q {
              addr = x;
              port = 443;
            })
            (K.membero x [
              "10.0.1.1"
              "10.0.1.2"
            ])
          ]
        )
      ) == [
        {
          addr = "10.0.1.1";
          port = 443;
        }
        {
          addr = "10.0.1.2";
          port = 443;
        }
      ]
      && K.runAll (q: K.eq { a = q; } { b = 1; }) == [ ]
      && K.runAll (q: K.eq [ q 1 ] [ 2 3 ]) == [ ]
      &&
        K.runAll (
          q:
          K.eq
            {
              addr = q;
              port = 443;
            }
            {
              addr = "10.0.1.1";
              port = 443;
            }
        ) == [ "10.0.1.1" ]; # record against record
    krn-fresh-occurs =
      K.run 1 (
        q:
        K.fresh (
          { x }:
          K.eq q [
            x
            x
          ]
        )
      ) == [
        [
          "_.0"
          "_.0"
        ]
      ]
      && K.run 1 (q: K.eq q [ q ]) == [ ];
    krn-interleave =
      let
        fives =
          x:
          K.disj [
            (K.eq x 5)
            (fives x)
          ];
        sixes =
          x:
          K.disj [
            (K.eq x 6)
            (sixes x)
          ];
      in
      K.run 4 (
        q:
        K.disj [
          (fives q)
          (sixes q)
        ]
      ) == [
        5
        6
        5
        6
      ];
    krn-cons-unbounded =
      K.run 3 (q: K.fresh ({ x, y }: [ (K.appendo x y q) ])) == [
        "_.0"
        {
          head = "_.0";
          tail = "_.1";
        }
        {
          head = "_.0";
          tail = {
            head = "_.1";
            tail = "_.2";
          };
        }
      ]
      &&
        K.run 2 (
          q:
          K.membero q (
            K.fromList [
              "x"
              "y"
            ]
          )
        ) == [
          "x"
          "y"
        ];
    krn-neq-store =
      K.runAll (q: [
        (K.neq q 1)
        (K.membero q [
          1
          2
          3
        ])
      ]) == [
        2
        3
      ] # =/= before the value: stored
      &&
        K.runAll (
          q:
          K.fresh (
            { a }:
            [
              (K.neq q { p = 1; })
              (K.eq q { p = a; })
              (K.membero a [
                1
                2
              ])
            ]
          )
        ) == [ { p = 2; } ]
      &&
        K.runC 1 (q: K.fresh ({ x }: [ (K.neq q x) ])) == [
          {
            value = "_.0";
            neq = [
              [
                [
                  "_.0"
                  "_.1"
                ]
              ]
            ];
            dom = { };
          }
        ]
      &&
        K.runAll (q: [
          (K.neq q 1)
          (K.eq q 1)
        ]) == [ ];
    krn-fd =
      K.runAll (
        q:
        K.fresh (
          { x, y }:
          [
            (K.infd [ x y ] 1 4)
            (K.plusfd x y 5)
            (K.eq q [
              x
              y
            ])
            (K.label [
              x
              y
            ])
          ]
        )
      ) == [
        [
          1
          4
        ]
        [
          2
          3
        ]
        [
          3
          2
        ]
        [
          4
          1
        ]
      ]
      &&
        K.runAll (
          q:
          K.fresh (
            {
              a,
              b,
              c,
            }:
            [
              (K.infd [ a b c ] 1 3)
              (K.distinctfd [
                a
                b
                c
              ])
              (K.ltfd a b)
              (K.eq q [
                a
                b
                c
              ])
              (K.label [
                a
                b
                c
              ])
            ]
          )
        ) == [
          [
            2
            3
            1
          ]
          [
            1
            2
            3
          ]
          [
            1
            3
            2
          ]
        ]
      &&
        K.runC 1 (q: [
          (K.infd [ q ] 2 5)
          (K.neqfd q 3)
        ]) == [
          {
            value = "_.0";
            neq = [ ];
            dom = {
              "_.0" = [
                2
                4
                5
              ];
            };
          }
        ]
      &&
        K.runAll (q: [
          (K.infd [ q ] 1 3)
          (K.lefd 5 q)
        ]) == [ ] # propagation alone fails it
      &&
        K.runAll (q: [
          (K.infd [ q ] 1 3)
          (K.eq q 7)
        ]) == [ ]
      &&
        K.runAll (q: [
          (K.eq q 2)
          (K.infd [ q ] 1 3)
        ]) == [ 2 ] # a bound value meets its domain
      &&
        map (a: a.dom) (
          K.runC 1 (
            q:
            K.fresh (
              { x, y }:
              [
                (K.infd [ x y ] 1 3)
                (K.plusfd x y q)
                (K.infd [ q ] 0 99)
              ]
            )
          )
        ) == [
          {
            "_.0" = [
              2
              3
              4
              5
              6
            ];
          }
        ]; # the sum is bounded
    krn-neq =
      K.runAll (
        q:
        K.fresh (
          { a, b }:
          [
            (K.membero a [
              "x"
              "y"
            ])
            (K.membero b [
              "x"
              "y"
            ])
            (K.neq a b)
            (K.eq q [
              a
              b
            ])
          ]
        )
      ) == [
        [
          "x"
          "y"
        ]
        [
          "y"
          "x"
        ]
      ];
    not-cycle-undefined =
      let
        r = logic true;
        h = "top:t/host:h";
      in
      map (x: "${x.aspect}@${x.scope}") r.undefined == [
        "a@${h}"
        "b@${h}"
        "c@${h}"
        "v@${h}"
        "w@${h}/user:u"
      ] # within and has carry it across scopes
      && !r.active.a.${h}
      && !r.active.b.${h}
      && !r.active.c.${h}
      && msgs r == [ ];
    not-cycle-control =
      let
        r = logic false;
        h = "top:t/host:h";
      in
      r.undefined == [ ] && !r.active.a.${h} && r.active.b.${h} && r.active.c.${h};
    positive-cycle-false =
      let
        r = logic true;
      in
      !r.active.p."top:t/host:h" && !b.any (x: x.aspect == "p" || x.aspect == "q") r.undefined;
    within-has-no-cycle =
      let
        r = logic false;
      in
      r.active.w."top:t/host:h/user:u" && r.active.v."top:t/host:h";
    diamond-memo = (diamond 60).active.x60."top:t/host:h";
    good-no-errors = msgs good == [ ];
    good-persist = good.reduced.persist."fleet:main/host:lb" == [ "/var/lib/motd" ];
    good-flake =
      good.flake.nixosConfigurations.lb == [ { environment.etc.motd.text = "/var/lib/motd"; } ];
    neg-missing-addr = has noAddr "missing addr";
    neg-missing-addr-no-flake-break =
      noAddr.reduced.persist."fleet:main/host:lb" == [ "/var/lib/motd" ];
    neg-unknown-field = has (sven.eval (fleet {
      addr = "a";
      adr = "b";
    })) "unknown field adr";
    neg-bad-check = has (sven.eval (fleet {
      addr = 1;
    })) "addr fails its check";
    bad-check-reads-null =
      (hostOf (
        sven.eval (fleet {
          addr = 1;
        })
      )).addr == null;
    two-answers = has (sven.eval {
      imports = [
        (fleet { addr = "a"; })
        { sven.host.lb.addr = "b"; }
      ];
    }) "two answers for host.lb.addr";
    same-answer-twice-ok =
      msgs (
        sven.eval {
          imports = [
            (fleet { addr = "a"; })
            { sven.host.lb.addr = "a"; }
          ];
        }
      ) == [ ];
    settings-value =
      (hostOf (feat {
        settings.zfs.arcMax = 8;
      })).settings.zfs.arcMax == 8;
    settings-default = (hostOf (feat { })).settings.k3s.role == "agent";
    settings-maybe-null = (hostOf (feat { })).settings.zfs.arcMax == null;
    settings-lazy = (hostOf featLazy).settings.k3s.role == "agent"; # reading zfs never forces settings.lazy's default
    settings-unknown = has (feat { settings.zfz = 1; }) "unknown field settings.zfz";
    order-default =
      ids (ordered 0) == [
        "fleet:main"
        "fleet:main/host:a"
        "fleet:main/host:b"
        "fleet:main/host:c"
      ];
    order-first =
      ids (ordered (-1)) == [
        "fleet:main"
        "fleet:main/host:c"
        "fleet:main/host:a"
        "fleet:main/host:b"
      ];
    order-bad = has (ordered "x") "order is not a number";
    q5-required = has (q5 ({ cluster, ... }: { })) "aspect k3s: arg `cluster` has no answer";
    q5-optional =
      !(b.any (m: b.match ".*arg `cluster`.*" m != null) (
        msgs (
          q5 (
            {
              cluster ? null,
              ...
            }:
            { }
          )
        )
      ));
    q5-emitted = has (q5 (
      {
        cluster ? null,
        ...
      }:
      { }
    )) "no cluster: k3s off";
    cycle-many-elements =
      (sven.eval (
        { sven, ... }:
        {
          sven.kinds.top = {
            spawns = { };
            sinks.many.reduce = sven.lib.reduce.list;
          };
          sven.top.t = { };
          sven.aspects.m = {
            at = sven.kinds.top;
            cycle = _: {
              many = [
                "a"
                "b"
                "c"
              ];
            };
          };
        }
      )).reduced.many."top:t" == [
        "a"
        "b"
        "c"
      ];
    tree-nearest =
      treeHit.reduced.seen."top:t/cluster:c1/node:n1" or null == [ "c1" ]
      && map (e: e.error) treeHit.errors == [ ];
    unread-sink-no-error =
      msgs (
        sven.eval {
          imports = [
            (fleet { addr = "a"; })
            { sven.aspects.motd.nixso = { }; }
          ];
        }
      ) == [ ];
    args-flow-down = (hostOf argsDown).addr == "hi" && msgs argsDown == [ ];
    args-missing = has argsMissing "module root/0: arg `nope` has no answer";
    presence-spawns =
      ids presence == [
        "top:t"
        "top:t/host:a"
        "top:t/host:a/svc:web"
        "top:t/host:b"
      ]
      && msgs presence == [ ];
    gap-derived-default =
      (b.head (b.filter (s: s.name == "h1") gaps.scopes)).vpn == "vpn-h1"
      && (b.head (b.filter (s: s.name == "h2") gaps.scopes)).vpn == "custom";
    gap-multi-file-functions =
      gaps.reduced.nixos."fleet:main/host:h1" == [
        [ "a-h1" ]
        [ "b-h1" ]
        "marker"
      ]
      && !(has gaps "two answers for aspects.multi.nixos");
    sink-arg-element-per-receiver =
      sinkArgs.reduced.seen."fleet:main" == [
        "prod"
        "staging"
      ]
      && msgs sinkArgs == [ ]; # a and c read one tag: once
    gap-static-once-per-receiver =
      b.length (b.filter (v: v == "marker") gaps.reduced.nixos."fleet:main/host:h1") == 1;
    gap-bad-at = has gaps "`at` holds a string, not a predicate";
    graph-edges = b.elem {
      sink = "persist";
      from = "fleet:main/host:lb";
      to = "fleet:main/host:lb";
      origin = "aspect motd";
    } good.graph.edges;
    deep-1000 = b.length (deep 1000).scopes == 1002;
    empty-fleet =
      msgs (sven.eval { }) == [ ] && (sven.eval { }).scopes == [ ] && (sven.eval { }).flake == null; # den-hoag empty-aspects
    wide-3000 = b.length (wide 3000).scopes == 3001;
  };
in
{
  inherit
    checks
    logic
    ports
    portsBase
    sven
    ;
  # the lib suites live in their own files; `failed` runs them all
  failed =
    b.filter (n: !checks.${n}) (b.attrNames checks)
    ++ map (n: "datalog/${n}") (import ./datalog.nix).failed
    ++ map (n: "rdf/${n}") (import ./rdf.nix).failed
    ++ map (n: "krn/${n}") (import ./krn.nix).failed
    ++ map (n: "shacl/${n}") (import ./shacl.nix).failed;
}
