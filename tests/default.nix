# yen oracles. Run: nix-instantiate --eval --strict vic/tests -A failed   (expect [ ])
let
  yen = (import ../default.nix).lib;
  impactOf = (import ../lib/impact.nix).impactOf;
  b = builtins;
  # a fastest test: { expr; expected; }
  eq = expr: expected: { inherit expr expected; };
  yes = x: eq x true;
  no = x: eq x false;
  msgs = r: map (e: e.error) r.errors;
  has = r: m: b.elem m (msgs r);

  # the design §1 fleet; nixosSystem replaced by the module list
  fleet =
    extra:
    { yen, ... }:
    {
      yen.kinds.fleet = {
        spawns.host = _: yen.host;
        sinks.out.reduce = yen.lib.reduce.merge;
      };
      yen.kinds.host = {
        fields.addr = yen.lib.is b.isString;
        sinks.persist.reduce = yen.lib.reduce.set;
        sinks.nixos.out =
          { host, nixos, ... }:
          {
            nixosConfigurations.${host.name} = nixos;
          };
      };
      yen.fleet.main = { };
      yen.host.lb = extra;
      yen.aspects.motd = {
        at = yen.kinds.host;
        persist = "/var/lib/motd";
        nixos =
          { persist, ... }:
          {
            environment.etc.motd.text = b.concatStringsSep "\n" persist;
          };
      };
      yen.flake = { out, ... }: out;
    };
  good = yen.eval (fleet {
    addr = "10.0.1.1";
  });
  noAddr = yen.eval (fleet { });

  # §4: two feature files, types at two paths of one field; no merge
  settings = [
    (
      { yen, ... }:
      {
        yen.kinds.host.fields.settings.zfs.arcMax = yen.lib.maybe (yen.lib.is b.isInt);
      }
    )
    (
      { yen, ... }:
      {
        yen.kinds.host.fields.settings.k3s.role = yen.lib.opt (yen.lib.is b.isString) "agent";
      }
    )
  ];
  feat = data: yen.eval { imports = [ (fleet ({ addr = "a"; } // data)) ] ++ settings; };
  featLazy = yen.eval {
    imports = [
      (fleet { addr = "a"; })
      (
        { yen, ... }:
        {
          yen.kinds.host.fields.settings.lazy = yen.lib.opt (yen.lib.is b.isString) (throw "touched");
        }
      )
    ]
    ++ settings;
  };
  hostOf = r: b.head (b.filter (s: s.kind == "host") r.scopes);

  # §5: order is a sink; siblings by (order, key), parent first
  ordered =
    o:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.fleet.spawns.host = _: yen.host;
        yen.kinds.host = { };
        yen.fleet.main = { };
        yen.host = {
          a = { };
          b = { };
          c = { };
        };
        yen.aspects.c-first = {
          at = yen.host.c;
          order = o;
        };
      }
    );
  ids = r: map (s: s.id) r.scopes;

  # Q5: an arg nobody answers; the component may emit on `errors`
  q5 =
    arg:
    yen.eval (
      { yen, ... }:
      {
        imports = [ (fleet { addr = "a"; }) ];
        yen.kinds.cluster = { };
        yen.aspects.k3s = {
          at = yen.kinds.host;
          nixos = arg;
        };
        yen.aspects.warn = {
          at = yen.kinds.host;
          cycle =
            { tree, ... }:
            let
              c.nearest = yen.kinds.cluster;
            in
            {
              tree = [ c ];
              errors = if tree.select c == [ ] then [ "no cluster: k3s off" ] else [ ];
            };
        };
      }
    );

  # imports nest; `_module.args` flow down to them
  argsDown = yen.eval {
    _module.args.greeting = "hi";
    imports = [
      {
        imports = [
          (
            { yen, greeting, ... }:
            {
              imports = [ (fleet { addr = greeting; }) ];
            }
          )
        ];
      }
    ];
  };
  argsMissing = yen.eval { imports = [ ({ nope, ... }: { }) ]; };

  # stack safety: a chain 3000 deep, a fan-out of 3000
  deep =
    n:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.node.spawns.node =
          s:
          let
            i = b.fromJSON (b.substring 5 9 s.key);
          in
          if i < n then { "${toString (i + 1)}" = { }; } else { };
        yen.kinds.top.spawns.node = _: { "0" = { }; };
        yen.top.t = { };
      }
    );
  wide =
    n:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.root.spawns.leaf =
          _:
          b.listToAttrs (
            b.genList (i: {
              name = toString i;
              value = { };
            }) n
          );
        yen.kinds.leaf = { };
        yen.root.r = { };
      }
    );

  # tree driver, positive: a node reads its nearest cluster
  treeHit = yen.eval (
    { yen, ... }:
    {
      yen.kinds.top.spawns.cluster = _: yen.cluster;
      yen.kinds.cluster.spawns.node = _: { n1 = { }; };
      yen.kinds.node.sinks.seen = { };
      yen.top.t = { };
      yen.cluster.c1 = { };
      yen.aspects.see = {
        at = yen.kinds.node;
        cycle =
          { tree, ... }:
          let
            c.nearest = yen.kinds.cluster;
          in
          {
            tree = [ c ];
            seen = map (c: c.name) (tree.select c);
          };
      };
    }
  );
  # every tree request at one node: parent, a nearest with no answer, children, scopesOf, holds, one unknown
  treeAll = treeAllWith false;
  treeAllWith =
    bogus:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.top.spawns.cluster = _: yen.cluster;
        yen.kinds.cluster.spawns.node = _: { n1 = { }; };
        yen.kinds.node.spawns.pod = _: {
          p1 = { };
          p2 = { };
        };
        yen.kinds.node.sinks.seen = { };
        yen.kinds.pod = { };
        yen.top.t = { };
        yen.cluster.c1 = { };
        yen.aspects.see = {
          at = yen.kinds.node;
          cycle =
            { tree, ... }:
            let
              parent.parent = true;
              none.nearest = yen.kinds.pod; # no pod above a node: no answer
              kids.children = yen.kinds.pod;
              same.scopesOf = yen.cluster.c1;
              holds.holds = yen.kinds.node;
              all.instances = yen.kinds.cluster;
              bad = {
                category = "bad"; # a name: refused, a request is selected by itself
                holds = yen.kinds.pod;
              };
            in
            {
              tree = [
                parent
                none
                kids
                same
                holds
                all
              ]
              ++ b.filter (_: bogus) [ bad ];
              seen = {
                parent = map (s: s.id) (tree.select parent);
                none = tree.select none;
                kids = map (map (s: s.name)) (tree.select kids);
                same = map (map (s: s.id)) (tree.select same);
                holds = tree.select holds;
                all = map (map (c: c.name)) (tree.select all);
                bad = tree.select bad; # not asked: no answer
              };
            };
        };
      }
    );
  # one error per code: a module, spawns, an element, a sink `of`, an order
  codesFix = yen.eval {
    imports = [
      (
        { yen, ... }:
        {
          yen.kinds.top = {
            spawns.host = _: {
              a = { };
              b = 3; # spawns: an instance that is no attrset
            };
            sinks.port.of = yen.lib.is builtins.isInt;
          };
          yen.kinds.host.spawns.svc = _: 1; # spawns: no attrset
          yen.kinds.svc = { };
          yen.top.t = { };
          yen.aspects.bare = {
            at = yen.kinds.top;
            port = x: x; # bare-function
          };
          yen.aspects.treeArg = {
            at = yen.kinds.top;
            port = { tree, ... }: 1; # arg: `tree` is a cycle source
          };
          yen.aspects.noArg = {
            at = yen.kinds.top;
            port = { host, ... }: 1; # arg: no host above top
          };
          yen.aspects.badOf = {
            at = yen.kinds.top;
            port = "x"; # of
          };
          yen.aspects.ord = {
            at = yen.kinds.top;
            order = "first"; # order
          };
        }
      )
      ({ nope }: { }) # module
    ];
  };
  # what NixOS `config` (a fixpoint) expresses, in yen. Each line names the NixOS pattern.
  configLike = yen.eval (
    { yen, ... }:
    let
      one = yen.lib.reduce.one;
    in
    {
      yen.kinds.fleet = {
        spawns.host = _: yen.host;
        sinks.addrs.reduce = yen.lib.reduce.merge; # a value every host gives, read by every host
      };
      yen.kinds.host = {
        fields.addr = yen.lib.is builtins.isString;
        fields.fqdn = yen.lib.derive (yen.lib.is builtins.isString) (i: "${i.name}.lan"); # default = f config
        sinks = {
          ports.reduce = yen.lib.reduce.set; # a list option many modules define
          firewall.reduce = one;
          settings.reduce = yen.lib.reduce.merge; # an attrset option, deep-merged
          motd.reduce =
            es: # mkForce / mkDefault: the lowest priority number wins
            {
              value = (builtins.head (builtins.sort (a: c: a.value.prio < c.value.prio) es)).value.text;
              errors = [ ];
            };
          chain.reduce = one;
          mid.reduce = one;
          leaf.reduce = one;
          peers.reduce = one;
        };
      };
      yen.fleet.main = { };
      yen.host = {
        a.addr = "10.0.0.1";
        b.addr = "10.0.0.2";
      };
      yen.aspects = {
        # declared before what it reads: the order of definitions never matters
        chain = {
          at = yen.kinds.host;
          chain = { mid, ... }: mid * 10;
        };
        mid = {
          at = yen.kinds.host;
          mid = { leaf, ... }: leaf + 1;
        };
        leaf = {
          at = yen.kinds.host;
          leaf = 1;
        };
        web = {
          at = yen.host.a;
          ports = 80;
        };
        ssh = {
          at = yen.kinds.host;
          ports = 22;
        };
        tls = {
          at = yen.aspects.web; # mkIf config.services.web.enable
          ports = 443;
        };
        fw = {
          at = yen.kinds.host;
          firewall = { ports, ... }: builtins.sort builtins.lessThan ports; # an option read from another option
        };
        base = {
          at = yen.kinds.host;
          settings.a = 1;
          motd = {
            prio = 1000;
            text = "default";
          };
        };
        tuned = {
          at = yen.host.b;
          settings.b.c = 2;
          motd = {
            prio = 50;
            text = "forced";
          };
        };
        addrs = {
          at = yen.kinds.host;
          addrs =
            { host, ... }:
            {
              ${host.name} = host.addr;
            };
          peers = { host, addrs, ... }: removeAttrs addrs [ host.name ]; # nodes.<other>.config
        };
      };
    }
  );
  # rung 1 (vic/formally-verified.md): the law gates outputs and stage; grants by path segment, edges and values
  # a rule is a function of its variables; its literals are references (yen.facts, yen.relations)
  nofw = id: [
    "bad"
    "fw"
    id
  ];
  hasFw = id: [
    "has"
    "firewall"
    id
  ];
  # a violation on one host: web runs sshd
  sshdWeb =
    { yen, ... }:
    {
      yen.invariants.no = _: {
        bad = [ ];
        pos = [ (yen.facts.has yen.aspects.sshd "top:t/host:web") ];
      };
    };
  # every host has the firewall aspect
  fwRules =
    yen:
    { H }:
    {
      bad = H;
      pos = [ (yen.facts.kind yen.kinds.host H) ];
      neg = [ (yen.facts.has yen.aspects.firewall H) ];
    };
  codes = r: map (e: e.code) r.errors;
  # rung 2 fixture: hosts `a` (tag "b:1") and `a:b` (tag "2"); `ok` is a user relation of arity 1; `rules yen` names
  # the invariants
  tagsWith =
    rules: hosts:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.top.spawns.host = _: yen.host;
        yen.kinds.host.fields.tag = yen.lib.is (_: true);
        yen.top.t = { };
        yen.host = {
          a.tag = "b:1";
          "a:b".tag = "2";
        }
        // hosts;
        yen.relations.ok = {
          arity = 1;
          check = ts: b.match "[0-9]+" (b.head ts) != null; # digits only: tag "b:1" fails, "2" passes
        };
        yen.invariants = rules yen;
      }
    );
  tags = rules: tagsWith rules { };
  rule2 =
    r:
    tags (_: {
      inherit r;
    });
  rung1 = extra: {
    imports = [
      (
        { yen, ... }:
        {
          yen.kinds.top = {
            spawns.host = _: yen.host;
          };
          yen.kinds.host = {
            fields.port = yen.lib.opt (yen.lib.is b.isInt) 22;
            fields.bypass = yen.lib.maybe (yen.lib.is b.isBool);
            sinks.nixos.reduce = yen.lib.reduce.merge;
            sinks.fw = { };
          };
          yen.top.t = { };
          yen.host = {
            web = { };
            webhook = { };
            db = { };
          };
          yen.aspects.sshd = {
            at = yen.kinds.host;
            nixos =
              { host, ... }:
              {
                ports = [ host.port ];
              };
          };
          yen.aspects.fw = {
            at = yen.lib.all [
              yen.kinds.host
              (s: s.bypass == null)
            ];
            fw = "on";
          };
          yen.aspects.cyc.at = [ ];
          yen.relations = {
            p.arity = 0;
            q.arity = 0;
          };
          yen.invariants.cycle = [
            (_: {
              head = yen.relations.p;
              pos = [ (yen.facts.has yen.aspects.cyc "top:t") ];
              neg = [ yen.relations.q ];
            })
            (_: {
              head = yen.relations.q;
              pos = [ (yen.facts.has yen.aspects.cyc "top:t") ];
              neg = [ yen.relations.p ];
            })
            (_: {
              bad = [ ];
              pos = [ yen.relations.p ];
            })
          ];
          yen.flake.ok = true; # outputs exist only when the fleet is clean
        }
      )
    ]
    ++ extra;
  };
  r1stage =
    change: grant:
    yen.stage {
      base = rung1 [ ];
      inherit change grant;
    };
  r1grant = yen.grant { scopes = [ "top:t/host:web" ]; };
  r1outside =
    s: b.sort b.lessThan (map (e: e.got) (b.filter (e: e.code == "outside-grant") s.refused));
  # structure from presence (Den #525): a child exists only where an aspect holds at its parent
  presence = yen.eval (
    { yen, ... }:
    {
      yen.kinds.top.spawns.host = _: yen.host;
      yen.kinds.host.spawns.svc = p: if yen.lib.holds yen.aspects.server p then { web = { }; } else { };
      yen.kinds.svc = { };
      yen.top.t = { };
      yen.host = {
        a = { };
        b = { };
      };
      yen.aspects.server.at = yen.host.a;
    }
  );
  # a function element that reads a sink: two givers whose sink values differ are two elements, not one
  sinkArgs = yen.eval (
    { yen, ... }:
    {
      yen.kinds.fleet = {
        spawns.environment = _: yen.environment;
        sinks.seen = { };
      };
      yen.kinds.environment = {
        spawns.host =
          s:
          b.listToAttrs (
            map (n: {
              name = n;
              value = yen.host.${n};
            }) (b.filter (n: yen.host.${n}.environment.name == s.name) (b.attrNames yen.host))
          );
        sinks.tag.reduce = yen.lib.reduce.one;
      };
      yen.kinds.host.fields.environment = yen.kinds.environment;
      yen.fleet.main = { };
      yen.environment = {
        prod = { };
        staging = { };
      };
      yen.host = {
        a.environment = yen.environment.prod;
        b.environment = yen.environment.staging;
        c.environment = yen.environment.prod;
      };
      yen.aspects.envtag = {
        at = yen.kinds.environment;
        tag = { environment, ... }: environment.name;
      };
      yen.aspects.report = {
        at = yen.kinds.host;
        seen = { tag, ... }: tag;
      };
    }
  );

  # Den CI gaps closed: derived defaults, bad `at`, one key from many files, static once per receiver
  gaps = yen.eval gapsModule;
  gapsBadAt = yen.eval {
    imports = [
      gapsModule
      { yen.aspects.typo.at = "host"; }
    ];
  };
  gapsModule =
    { yen, ... }:
    {
      imports = [
        { yen.aspects.multi.nixos = { scope, ... }: [ "a-${scope.name}" ]; }
        { yen.aspects.multi.nixos = { scope, ... }: [ "b-${scope.name}" ]; }
      ];
      yen.kinds.fleet = {
        spawns.host = _: yen.host;
      };
      yen.kinds.host = {
        fields.vpn = yen.lib.derive (yen.lib.is b.isString) (self: "vpn-${self.name}");
        spawns.user = _: {
          u1 = { };
          u2 = { };
        };
        sinks.nixos = { };
      };
      yen.kinds.user = { };
      yen.fleet.main = { };
      yen.host = {
        h1 = { };
        h2.vpn = "custom";
      };
      yen.aspects.multi.at = yen.kinds.host;
      yen.aspects.shared = {
        at = [
          yen.kinds.host
          yen.kinds.user
        ];
        nixos = "marker";
      };
    };
  # aspect refs on cycles: three values (well-founded semantics)
  logic =
    cyclic:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.top.spawns.host = _: yen.host;
        yen.kinds.host.spawns.user = _: { u = { }; };
        yen.kinds.user = { };
        yen.top.t = { };
        yen.host.h = { };
        yen.aspects =
          let
            inherit (yen.lib)
              all
              not
              within
              has
              ;
          in
          {
            a.at = all [
              yen.kinds.host
              (not yen.aspects.b)
            ];
            b.at =
              if cyclic then
                all [
                  yen.kinds.host
                  (not yen.aspects.a)
                ]
              else
                yen.kinds.host;
            c.at = all [
              yen.kinds.host
              (not yen.aspects.a)
            ]; # reads an undefined: undefined too
            p.at = yen.aspects.q;
            q.at = yen.aspects.p; # a positive cycle: unfounded, false
            w.at = all [
              yen.kinds.user
              (within yen.aspects.b)
            ]; # within crosses scopes: no cycle
            v.at = all [
              yen.kinds.host
              (has yen.aspects.w)
            ];
          };
      }
    );
  diamond =
    k:
    yen.eval (
      { yen, ... }:
      {
        yen.kinds.top.spawns.host = _: yen.host;
        yen.kinds.host = { };
        yen.top.t = { };
        yen.host.h = { };
        yen.aspects = {
          x0.at = yen.kinds.host;
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
                value.at = yen.aspects.${p};
              }
              {
                name = "r${toString i}";
                value.at = yen.aspects.${p};
              }
              {
                name = "x${toString i}";
                value.at = yen.lib.all [
                  yen.aspects."l${toString i}"
                  yen.aspects."r${toString i}"
                ];
              }
            ]
          ) (b.genList (i: i + 1) k)
        );
      }
    );

  G = yen.graphs;
  D = yen.datalog;
  K = yen.krn;
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
    { yen, ... }:
    {
      yen.kinds.top.spawns.host = _: yen.host;
      yen.kinds.host = {
        fields.port = {
          check = p: b.isInt p && p < 65536;
          name = "Port";
        };
        sinks.fw = { };
      };
      yen.top.t = { };
      yen.host = {
        a.port = 22;
        b.port = 80;
      };
      yen.aspects.firewall = {
        at = yen.host.a;
        fw = "on";
      };
      yen.invariants.fw = fwRules yen;
    };
  ports =
    extra:
    yen.eval (
      { yen, ... }:
      {
        imports = [ extra ];
        yen.kinds.top.spawns.host = _: yen.host;
        yen.kinds.host = {
          fields.port = {
            check = p: b.isInt p && p < 65536;
            name = "Port";
          };
          sinks.fw = { };
        };
        yen.top.t = { };
        yen.host = {
          a.port = 22;
          b.port = 80;
        };
        yen.aspects.firewall = {
          at = yen.host.a;
          fw = "on";
        };
        yen.invariants.fw = fwRules yen;
      }
    );
  rec1 = r: code: b.head (b.filter (e: e.code == code) r.errors);

  checks = {
    errors-v2-check =
      let
        e = rec1 (ports { yen.host.c.port = 70000; }) "check";
      in
      {
        want = eq e.want "Port";
        path = eq e.path [ "port" ];
        got = eq e.got 70000;
        class = eq e.class "fixable";
        from = eq e.from "host:c";
        error = eq e.error "port fails its check";
      };
    errors-v2-near = {
      close = eq (rec1 (ports { yen.host.b.prot = 1; }) "unknown-field").near [ "port" ];
      far = eq (rec1 (ports { yen.host.b.zzzzzz = 1; }) "unknown-field").near [ ];
    };
    errors-v2-two-answers =
      let
        e = rec1 (ports { yen.host.a.port = 23; }) "two-answers";
      in
      {
        path = eq e.path [
          "host"
          "a"
          "port"
        ];
        got = eq e.got 2;
      };
    declared-in =
      let
        r = ports { yen.aspects.firewall.nixos = { }; };
      in
      {
        two-files = eq (b.length (
          r.declaredIn [
            "aspects"
            "firewall"
          ]
        )) 2;
        none = eq (r.declaredIn [
          "aspects"
          "nope"
        ]) [ ];
      };
    invariants-check =
      let
        r = ports { };
      in
      {
        violations = eq r.check.violations [ (nofw "top:t/host:b") ];
        incomplete = eq r.check.incomplete [ ];
        not-ok = no r.check.ok;
        fixed-ok =
          yes
            (ports (
              { yen, ... }:
              {
                yen.aspects.fw-b = {
                  at = yen.host.b;
                  fw = "on";
                };
                yen.aspects.firewall.at = yen.host.b;
              }
            )).check.ok;
      };
    invariants-incomplete =
      let
        # ok "loop" holds when it does not: undefined, and so is the `bad` it proves
        r = ports (
          { yen, ... }:
          {
            yen.relations.ok.arity = 1;
            yen.invariants.loop = [
              (_: {
                head = yen.relations.ok "loop";
                neg = [ (yen.relations.ok "loop") ];
              })
              (_: {
                bad = [ ];
                pos = [ (yen.relations.ok "loop") ];
              })
            ];
          }
        );
        loop = [
          "bad"
          "loop"
        ];
      in
      {
        incomplete = eq r.check.incomplete [ loop ];
        not-violation = no (b.elem loop r.check.violations);
        not-ok = no r.check.ok;
      };
    schema-exact =
      let
        s =
          (ports (
            { yen, ... }:
            {
              yen.kinds.host.sinks.tags.reduce = yen.lib.reduce.set;
            }
          )).schema;
      in
      {
        host = eq s.kinds.host {
          fields.port.type = "Port";
          spawns = [ ];
          instances = 2;
          scopes = 2;
          sinks = {
            fw = {
              reduce = "list";
              of = null;
              feeds = [ ];
              conditional = false;
            };
            tags = {
              reduce = "set";
              of = null;
              feeds = [ ];
              conditional = false;
            };
          };
        };
        top-spawns = eq s.kinds.top.spawns [ "host" ];
        firewall = eq s.aspects.firewall {
          keys = [ "fw" ];
          cycle = false;
          files = [ "root" ];
          activeAt = 1;
        };
        invariants = eq s.invariants [ "fw" ];
        json = yes (b.isString (b.toJSON s));
      };
    explain =
      let
        r = ports (
          { yen, ... }:
          {
            yen.aspects.both.at = yen.lib.all [
              yen.kinds.host
              (yen.lib.not yen.aspects.firewall)
            ];
          }
        );
        e = r.explain "both" "top:t/host:b" 3;
        all' = b.head e.at.kids;
      in
      {
        active = yes e.active;
        op = eq all'.op "all";
        kids = eq (map (k: k.op) all'.kids) [
          "kind"
          "not"
        ];
        not-value = eq (b.head (b.elemAt all'.kids 1).kids).value false;
        cut = eq (b.head (r.explain "both" "top:t/host:a" 1).at.kids).kids "cut";
        near = eq (r.explain "bth" "top:t/host:a" 1).near [ "both" ];
        unknown-scope = eq (r.explain "both" "top:t/host:z" 1).code "unknown-scope";
        gives = eq (r.explain "firewall" "top:t/host:a" 2).gives [
          {
            sink = "fw";
            to = "top:t/host:a";
          }
        ];
      };
    stage-ok-and-diff =
      let
        base = {
          imports = [ portsBase ];
        };
        s = yen.stage {
          inherit base;
          change = {
            yen = {
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
      {
        ok = yes s.ok;
        added = eq s.diff.scopes.added [ "top:t/host:c" ];
        removed = eq s.diff.scopes.removed [ ];
        sha = yes (b.isString s.sha);
        active = eq s.diff.active.added [ "firewall@top:t/host:c" ];
        render =
          eq
            (yen.stage {
              inherit base;
              change = b.fromJSON s.render;
            }).diff
            s.diff;
      };
    stage-refuses =
      let
        base = {
          imports = [ portsBase ];
        };
        ch = yen.change.set [ "host" "a" "port" ] 23;
        s = yen.stage {
          inherit base;
          change = ch;
        };
        v = yen.stage {
          inherit base;
          change = yen.change.set [ "host" "c" "port" ] 1;
        };
      in
      {
        not-ok = no s.ok;
        two-answers = yes (b.any (e: e.code == "two-answers") s.errors);
        rejected =
          eq
            (b.head
              (yen.stage {
                inherit base;
                change = ch;
                rejected = [ s.sha ];
              }).refused
            ).class
            "authority";
        violation = eq v.violations [ (nofw "top:t/host:c") ];
        violation-errors = eq v.errors [ ];
        violation-not-ok = no v.ok;
      };
    grants-narrow =
      let
        g = yen.grant {
          scopes = [ "top:t/host:a" ];
          sinks = [ "fw" ];
        };
        all' = yen.grant { scopes = [ "top:t" ]; };
        e = to: sink: { inherit to sink; };
      in
      {
        allowed = yes (yen.allowed g (e "top:t/host:a" "fw"));
        other-scope = no (yen.allowed g (e "top:t/host:b" "fw"));
        other-sink = no (yen.allowed g (e "top:t/host:a" "nixos"));
        narrow-left = eq (yen.narrow all' g) g;
        narrow-right = eq (yen.narrow g all') g;
        narrow-disjoint = eq (yen.narrow g (yen.grant { scopes = [ "top:t/host:b" ]; })).scopes [ ];
        refused = yes (
          (yen.stage {
            base = {
              imports = [ portsBase ];
            };
            change = {
              yen.aspects.firewall.at = [
                {
                  kind = "host";
                  name = "b";
                }
              ];
            };
            grant = g;
          }).refused != [ ]
        );
      };
    agent-json =
      let
        a = yen.agent (ports {
          yen.host.c.port = 70000;
        });
      in
      {
        json = eq (b.fromJSON (b.toJSON a)) a;
        scopes = eq a.counts.scopes 4;
        errors = eq (b.length a.errors) 1;
        safe =
          eq
            (yen.jsonSafe {
              f = x: x;
              p = ./.;
            })
            {
              f = "<function>";
              p = toString ./.;
            };
      };
    agent-context =
      let
        r = ports (
          { yen, ... }:
          {
            yen.kinds.host.sinks.fw2 = { };
            yen.aspects.more = {
              at = yen.host.a;
              fw = "x";
              fw2 = "y";
            };
          }
        );
        c = r.context "top:t/host:a" { maxEdges = 1; };
      in
      {
        truncated = eq c.received.truncated {
          shown = 1;
          of = 3;
        };
        items = eq (b.length c.received.items) 1;
        aspects = eq c.aspects.items [
          "firewall"
          "more"
        ];
        parent = eq c.parent "top:t";
        unknown = eq (r.context "top:t/host:q" { }).code "unknown-scope";
        near = eq (b.length (r.context "top:t/host:q" { }).near) 2;
        json = eq (b.fromJSON (b.toJSON c)) c;
      };
    stored-queries =
      let
        # a parameter is typed; from JSON, a ref is its identity: { kind; name; }, { kind; } or { aspect; }
        r = ports (
          { yen, ... }:
          {
            yen.queries = {
              portOf = {
                params.host = yen.kinds.host;
                answer = { host, result }: host.port;
              };
              count = {
                params.kind = yen.lib.opt yen.lib.kind yen.kinds.host;
                answer = { kind, result }: b.length (b.filter (yen.lib.holds kind) result.scopes);
              };
              on = {
                params.aspect = yen.lib.aspect;
                answer =
                  { aspect, result }: b.filter (id: result.active.${aspect.__aspect}.${id}) [ "top:t/host:a" ];
              };
              untyped = { result }: 1;
            };
          }
        );
        hostB = {
          kind = "host";
          name = "b";
        };
      in
      {
        catalog = eq (removeAttrs r.queries [ "untyped" ]) {
          count = {
            required = [ ];
            optional = [ "kind" ];
            types.kind = "a kind";
          };
          on = {
            required = [ "aspect" ];
            optional = [ ];
            types.aspect = "an aspect";
          };
          portOf = {
            required = [ "host" ];
            optional = [ ];
            types.host = "a host ref";
          };
        };
        port = eq (r.ask "portOf" { host = hostB; }) 80;
        # negative controls: a name string, an unknown instance and a ref of another kind are refused, never asked
        port-string = eq (r.ask "portOf" { host = "b"; }).code "ref";
        port-unknown =
          eq
            (r.ask "portOf" {
              host = hostB // {
                name = "c";
              };
            }).code
            "unknown-instance";
        port-other-kind =
          eq
            (r.ask "portOf" {
              host = hostB // {
                kind = "top";
                name = "t";
              };
            }).code
            "ref";
        count = eq (r.ask "count" { }) 2;
        count-kind = eq (r.ask "count" { kind.kind = "top"; }) 1;
        count-string = eq (r.ask "count" { kind = "top"; }).code "check";
        on = eq (r.ask "on" { aspect.aspect = "firewall"; }) [ "top:t/host:a" ];
        untyped = eq (r.ask "untyped" { }).code "query-untyped";
        untyped-error = eq (map (e: e.code) (b.filter (e: e.code == "query-untyped") r.errors)) [
          "query-untyped"
        ];
        missing = eq (r.ask "portOf" { }).code "missing-param";
        unknown-param =
          eq
            (r.ask "portOf" {
              host = hostB;
              hots = 1;
            }).code
            "unknown-param";
        near = eq (r.ask "portof" { }).near [ "portOf" ];
      };
    history =
      let
        h = yen.history {
          url = "https://github.com/vic/yen"; # the rev is on main; a flake eval has no .git to read
          revs = [
            "df8ee68d5244aeca4e4bf23f1e9ecc927226d620"
          ];
          module = "tests/fixtures/history.nix";
        };
      in
      {
        changes = eq (b.elemAt h 0).changes [ ];
        as-of =
          eq
            (yen.asOf {
              url = "https://github.com/vic/yen"; # the rev is on main; a flake eval has no .git to read
              rev = "df8ee68d5244aeca4e4bf23f1e9ecc927226d620";
              module = "tests/fixtures/history.nix";
            }).data.host.a.port
            22;
      };
    # flat joins list elements and keeps scalars; the first of a duplicate stays, so the order is the order of arrival
    reduce-flat =
      eq
        (yen.reduce.flat (
          map (value: { inherit value; }) [
            [
              1
              2
            ]
            3
            [
              2
              4
            ]
            [ ]
            1
          ]
        ))
        {
          value = [
            1
            2
            3
            4
          ];
          errors = [ ];
        };
    reduce-flat-empty = eq (yen.reduce.flat [ ]) {
      value = [ ];
      errors = [ ];
    };
    # enum and attrsOf are types: a check, and a description for the error record
    # enum and attrsOf are types: a check, and a description for the error record
    type-enum =
      eq
        [
          (
            (yen.enum [
              "a"
              "b"
            ]).check
            "a"
          )
          (
            (yen.enum [
              "a"
              "b"
            ]).check
            "c"
          )
          (yen.enum [
            "a"
            "b"
          ]).description
        ]
        [
          true
          false
          "one of \"a\", \"b\""
        ];
    type-attrsOf =
      eq
        [
          ((yen.attrsOf (yen.is b.isInt)).check { x = 1; })
          ((yen.attrsOf (yen.is b.isInt)).check { x = "1"; })
          ((yen.attrsOf (yen.is b.isInt)).check { })
          ((yen.attrsOf (yen.is b.isInt)).check [ 1 ])
        ]
        [
          true
          false
          true
          false
        ];
    # reduce errors name their receiver and sink: a strategy cannot know them, the engine sets them
    reduce-error-receiver =
      let
        r = yen.eval (
          { yen, ... }:
          {
            yen.kinds.top = {
              spawns.h = _: yen.h;
            };
            yen.kinds.h.sinks.admin.reduce = yen.lib.reduce.one;
            yen.top.t = { };
            yen.h.a = { };
            yen.aspects.x = {
              at = yen.kinds.h;
              admin = "ana";
            };
            yen.aspects.y = {
              at = yen.kinds.h;
              admin = "bo";
            };
          }
        );
      in
      eq (b.map (e: { inherit (e) code from sink; }) r.errors) [
        {
          code = "one";
          from = "top:t/h:a";
          sink = "admin";
        }
      ];
    # an aspect's `errors` key gives records too; `from` is always the giving scope
    aspect-error-record =
      let
        r = yen.eval (
          { yen, ... }:
          {
            yen.kinds.top = {
              spawns.h = _: yen.h;
            };
            yen.kinds.h = { };
            yen.top.t = { };
            yen.h.a = { };
            yen.aspects.x = {
              at = yen.kinds.h;
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
      {
        records =
          eq
            (b.map (e: {
              inherit (e)
                code
                error
                from
                class
                ;
            }) r.errors)
            [
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
            ];
        fix = eq (b.head r.errors).fix "change one";
      };
    # a declared bound that is null is open
    valid-at-null = {
      open = yes (
        yen.validAt "2026-11-15" {
          validFrom = null;
          validTo = null;
        }
      );
      from = yes (
        yen.validAt "2026-11-15" {
          validFrom = "2026-01-01";
          validTo = null;
        }
      );
      to = no (
        yen.validAt "2026-11-15" {
          validFrom = null;
          validTo = "2026-10-31";
        }
      );
    };
    valid-at =
      let
        r = yen.eval (
          { yen, ... }:
          {
            imports = [ ./fixtures/history.nix ];
            yen.aspects.backup.at = yen.lib.all [
              yen.kinds.host
              (yen.lib.validAt "2026-11-15")
            ];
            yen.aspects.late.at = yen.lib.all [
              yen.kinds.host
              (yen.lib.validAt "2027-01-01")
            ];
          }
        );
      in
      {
        backup-a = yes r.active.backup."top:t/host:a";
        backup-b = yes r.active.backup."top:t/host:b";
        late-a = no r.active.late."top:t/host:a";
        late-b = yes r.active.late."top:t/host:b";
      };
    without =
      let
        w = yen.without {
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
      {
        dropped = eq w.dropped [ ./fixtures/without/db.nix ];
        no-db = yes (b.all (s: s.name != "db") w.result.scopes);
        web = yes (b.any (s: s.name == "web") w.result.scopes);
        nothing =
          eq
            (yen.without {
              files = [
                ./fixtures/without/base.nix
                ./fixtures/without/db.nix
              ];
              path = [
                "host"
                "nope"
              ];
            }).dropped
            [ ];
      };
    impact =
      let
        r = yen.eval {
          imports = [
            ./fixtures/without/base.nix
            ./fixtures/without/db.nix
          ];
        };
        i = r.impact "top:t/host:db" { };
      in
      {
        reached = eq i.reached [
          {
            scope = "top:t";
            depth = 1;
            via = "peers";
          }
        ];
        truncated = eq i.truncated {
          shown = 1;
          of = 1;
        };
        sinks = eq (r.impact "top:t/host:db" { sinks = [ "nixos" ]; }).reached [ ];
        unknown-sink = eq (r.impact "top:t/host:db" { sinks = [ "peer" ]; }).code "unknown-sink";
        unknown-scope = eq (r.impact "top:t/host:dd" { }).code "unknown-scope";
      };
    # .20: when a fleet has labels, an aspect from an unlabeled file has trust 0 (floor sees it); a prefix is literal,
    # never a regex ("agen./" does not label "agent/")
    labels-unlabeled =
      let
        r = yen.eval {
          imports = [
            ./fixtures/labels/modules/base.nix
            ./fixtures/labels/agent/web.nix
            { yen.aspects.extra.at = [ ]; }
          ];
        };
        lit = yen.eval {
          imports = [
            ./fixtures/labels/modules/base.nix
            ./fixtures/labels/agent/web.nix
            { yen.labels."agen./".trust = 0; } # as a regex it would match agent/ and win as the lowest
          ];
        };
      in
      {
        trust = eq r.labels.extra.trust 0;
        prefix = eq r.labels.extra.prefix null;
        literal = eq lit.labels.cache.trust 1;
      };
    # .20 .13: a staged change or a program carries its submitter's label; floor sees the agent, not a file
    labels-submitter =
      let
        base = {
          imports = [ ./fixtures/labels/modules/base.nix ];
        };
        s = yen.stage {
          inherit base;
          by = {
            name = "bot";
            trust = 1;
          };
          change = {
            yen.aspects.web.nixos.services.redis.enable = true;
          };
        };
        p = yen.program.dryRun {
          inherit base;
          by = {
            name = "bot";
            trust = 1;
          };
          prog = [
            {
              op = "place";
              aspect = "web";
              kind = "host";
              name = "h";
            }
          ];
        };
      in
      {
        by = eq s.labels.web.by "bot";
        trust = eq s.labels.web.trust 1;
        floor-web = yes (b.all (x: x.aspect == "web" && x.trust == 1) (s.floor 2));
        floor-some = yes (s.floor 2 != [ ]);
        program-by = eq p.labels.web.by "bot";
      };
    labels-floor =
      let
        r = yen.eval {
          imports = [
            ./fixtures/labels/modules/base.nix
            ./fixtures/labels/agent/web.nix
          ];
        };
      in
      {
        web = eq r.labels.web.trust 1;
        prefix = eq r.labels.web.prefix "agent/";
        cache = eq r.labels.cache.trust 1;
        floor-agent = yes (b.all (x: x.trust == 1 && b.match ".*agent/web.nix" x.file != null) (r.floor 3));
        floor-two = yes (b.length (r.floor 3) >= 2);
        floor-empty = eq (r.floor 1) [ ];
        base-only = eq (yen.eval { imports = [ ./fixtures/labels/modules/base.nix ]; }).labels.web.trust 3;
      };
    field-facts =
      let
        r = ports (
          { yen, ... }:
          {
            yen.kinds.host.fields.peer = yen.lib.maybe yen.kinds.host;
            yen.host.b.peer = yen.host.a;
          }
        );
      in
      {
        val = yes (b.elem [ "val" "port" "top:t/host:a" 22 ] r.facts);
        ref = yes (b.elem [ "ref" "peer" "top:t/host:b" "host" "a" ] r.facts);
        no-reverse = no (b.elem [ "ref" "peer" "top:t/host:a" "host" "b" ] r.facts);
      };
    check-whynot =
      let
        r = ports (
          { yen, ... }:
          {
            yen.aspects.fw-b = {
              at = yen.host.b;
              fw = "on";
            };
            yen.aspects.firewall.at = yen.host.b;
            # a literal by reference, built where the refs are: the scope term is an instance
            yen.flake =
              { ... }:
              {
                kindA = yen.facts.kind yen.kinds.host yen.host.a;
              };
          }
        );
        # an instance as a caller outside the fleet writes it: its identity
        host = name: {
          kind = "host";
          inherit name;
        };
        bad = r.check.bad.fw (host "b");
        twice = ports (
          { yen, ... }:
          {
            yen.kinds.top.spawns.host = _: yen.host;
            yen.kinds.second.spawns.host = _: yen.host;
            yen.second.s = { };
          }
        );
      in
      {
        ok = yes r.check.ok;
        blocking = yes (b.any (x: x.blocking == [ (hasFw "top:t/host:b") ]) (r.check.whyNot bad));
        proof = eq (r.check.proof r.flake.kindA).atom [
          "kind"
          "host"
          "top:t/host:a"
        ];
        holds = eq ((ports { }).check.whyNot ((ports { }).check.bad.fw (host "b"))) [ ];
        # a scope record is its own scope
        scope-record = eq (r.check.whyNot (
          r.check.bad.fw (b.head (b.filter (s: s.id == "top:t/host:b") r.scopes))
        )) (r.check.whyNot bad);
        # negative controls: a hand-written list is no literal; an instance with two scopes names no one scope
        list = eq (r.check.whyNot (nofw "top:t/host:b")).code "not-a-literal";
        ambiguous = eq (twice.check.why (twice.check.bad.fw (host "b"))).code "scope-ambiguous";
        unknown-instance = eq (r.check.why (r.check.bad.fw (host "z"))).code "scope-ambiguous";
      };
    # D10: explanations and the verdict read one model; a fact no rule mentions is still true
    explain-same-model =
      let
        c = (ports { }).check;
        a = c.facts.scope {
          kind = "host";
          name = "a";
        };
      in
      {
        proof = eq (c.proof a).atom [
          "scope"
          "top:t/host:a"
        ];
        why-not = eq (c.whyNot a) [ ];
      };
    program-validate =
      let
        r = ports { };
        v = yen.program.validate r;
      in
      {
        valid = eq (v [
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
        ]) [ ];
        near-kind = eq (map (e: e.near or null) (v [
          {
            op = "set";
            path = [
              "hots"
              "c"
              "port"
            ];
            value = 1;
          }
        ])) [ [ "host" ] ];
        near-field = eq (map (e: e.near or null) (v [
          {
            op = "set";
            path = [
              "host"
              "c"
              "prot"
            ];
            value = 1;
          }
        ])) [ [ "port" ] ];
        near-aspect = eq (map (e: e.near or null) (v [
          {
            op = "place";
            aspect = "firewal";
            kind = "host";
            name = "c";
          }
        ])) [ [ "firewall" ] ];
        near-op = eq (map (e: e.near or null) (v [ { op = "plac"; } ])) [ [ "place" ] ];
        empty-op = eq (b.length (v [ { } ])) 1;
      };
    program-dryrun =
      let
        base = {
          imports = [ portsBase ];
        };
        d =
          p:
          yen.program.dryRun {
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
      {
        ok = yes ok.ok;
        valid = yes ok.valid;
        added = eq ok.diff.scopes.added [ "top:t/host:c" ];
        sha = yes (b.isString ok.sha);
        bad-not-ok = no bad.ok;
        bad-violations = eq bad.violations [ (nofw "top:t/host:c") ];
        invalid =
          no
            (d [
              {
                op = "set";
                path = [ "hots" ];
                value = 1;
              }
            ]).valid;
        render =
          eq
            (b.fromJSON (
              yen.program.render [
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
            ))
            [
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
      };
    invariants-why =
      eq
        (b.head (
          (ports { }).check.why (
            (ports { }).check.bad.fw {
              kind = "host";
              name = "b";
            }
          )
        )).neg
        [
          (hasFw "top:t/host:b")
        ];
    graphs-reach = {
      app = eq (G.reach dag "app") [
        "cache"
        "db"
        "net"
      ];
      net = eq (G.reach dag "net") [ ];
      reachers = eq (G.reachers dag "net") [
        "app"
        "cache"
        "db"
      ];
    };
    graphs-topo = {
      dag = eq (G.topo dag) {
        ok = true;
        order = [
          "net"
          "cache"
          "db"
          "app"
        ];
        stuck = [ ];
      };
      ring-ok = eq (G.topo ring).ok false;
      ring-stuck = eq (G.topo ring).stuck [
        "a"
        "b"
        "c"
        "d"
      ];
    };
    graphs-layers = eq (G.layers dag) [
      [ "net" ]
      [
        "cache"
        "db"
      ]
      [ "app" ]
    ];
    graphs-cycles = {
      ring = eq (G.cycles ring) [
        "a"
        "b"
        "c"
      ];
      dag = eq (G.cycles dag) [ ];
      sccs = eq (G.sccs ring) [
        [
          "a"
          "b"
          "c"
        ]
      ];
    };
    graphs-paths = {
      shortest = eq (G.shortest ring "d" "c") [
        "d"
        "a"
        "b"
        "c"
      ];
      none = eq (G.shortest dag "net" "app") null;
      paths = eq (G.paths dag "app" "net") [
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
    };
    # a graph over refs: G.of nodes next; every answer is a node identity { kind; name; }, never a name string
    graphs-refs =
      let
        r = yen.eval (
          { yen, ... }:
          {
            yen.kinds.top.spawns.host = _: yen.host;
            yen.kinds.host.fields.dependsOn = yen.lib.opt (yen.lib.listOf yen.kinds.host) [ ];
            yen.top.t = { };
            yen.host = {
              db = { };
              lb.dependsOn = [ yen.host.web ];
              web.dependsOn = [ yen.host.db ];
            };
            yen.flake =
              { ... }:
              let
                g = G.of (b.attrValues yen.host) (h: h.dependsOn);
              in
              {
                layers = G.layers g;
                reach = G.reach g yen.host.lb;
                reachers = G.reachers g yen.host.db;
                shortest = G.shortest g yen.host.lb yen.host.db;
                topo = (G.topo g).order;
                transposed = G.reach (G.transpose g) yen.host.db;
                none = G.shortest g yen.host.db yen.host.lb;
              };
          }
        );
        h = name: {
          kind = "host";
          inherit name;
        };
      in
      {
        layers = eq r.flake.layers [
          [ (h "db") ]
          [ (h "web") ]
          [ (h "lb") ]
        ];
        reach = eq r.flake.reach [
          (h "db")
          (h "web")
        ];
        reachers = eq r.flake.reachers [
          (h "lb")
          (h "web")
        ];
        shortest = eq r.flake.shortest [
          (h "lb")
          (h "web")
          (h "db")
        ];
        topo = eq r.flake.topo [
          (h "db")
          (h "web")
          (h "lb")
        ];
        transposed = eq r.flake.transposed [
          (h "lb")
          (h "web")
        ];
        none = eq r.flake.none null;
      };
    datalog-wfs =
      let
        w = D.wfs choice;
      in
      {
        true = eq w.true [ "s" ];
        undefined = eq w.undefined [
          "a"
          "b"
          "c"
        ];
        false = eq w.false [
          "t"
          "u"
        ];
      };
    datalog-stratified =
      let
        w = D.wfs (choice ++ [ { head = "b"; } ]);
      in
      {
        true = eq w.true [
          "b"
          "s"
        ];
        undefined = eq w.undefined [ ];
        false = eq w.false [
          "a"
          "c"
          "t"
          "u"
        ];
      };
    datalog-stable = {
      choice = eq (D.stable choice) [
        [
          "b"
          "s"
        ]
        [
          "a"
          "c"
          "s"
        ]
      ];
      none = eq (D.stable [
        {
          head = "p";
          neg = [ "p" ];
        }
      ]) [ ];
    };
    datalog-why = {
      s = eq (D.why choice (D.wfs choice) "s") [ { head = "s"; } ];
      t = eq (D.why choice (D.wfs choice) "t") [ ];
    };
    # ground rules by reference: relations from yen.relations, terms are instances; no name is written as a string
    datalog-refs =
      let
        r = yen.eval (
          { yen, ... }:
          {
            yen.kinds.top.spawns.host = _: yen.host;
            yen.kinds.host.fields.web = yen.lib.opt (yen.lib.is b.isBool) false;
            yen.top.t = { };
            yen.host = {
              a.web = true;
              c = { };
            };
            yen.relations = {
              web.arity = 1;
              serves.arity = 1;
            };
            yen.flake =
              { ... }:
              let
                inherit (yen.relations) web serves;
                hosts = b.attrValues yen.host;
                rules =
                  map (h: {
                    head = serves h;
                    pos = [ (web h) ];
                  }) hosts
                  ++ map (h: { head = web h; }) (b.filter (h: h.web) hosts);
                m = yen.lib.datalog.wfs rules;
              in
              {
                serves = map (h: h.name) (b.filter (h: m.holds (serves h)) hosts);
                whyNot = map (x: x.missing) (yen.lib.datalog.whyNot rules m (serves yen.host.c));
                why = b.length (yen.lib.datalog.why rules m (serves yen.host.a));
                # an instance term is its identity: the same atom whatever its data
                atom = yen.lib.datalog.atom (serves yen.host.a);
              };
          }
        );
      in
      {
        serves = eq r.flake.serves [ "a" ];
        why = eq r.flake.why 1;
        why-not = eq r.flake.whyNot [
          [
            [
              "web"
              {
                kind = "host";
                name = "c";
              }
            ]
          ]
        ];
        atom = eq r.flake.atom [
          "serves"
          {
            kind = "host";
            name = "a";
          }
        ];
      };
    krn-backward = {
      t1 =
        eq
          (map (map K.toList) (
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
          ))
          ([
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
          ]);
      t2 =
        eq
          (map K.toList (
            K.run 1 (
              q:
              K.appendo (K.fromList [ 1 ]) (K.fromList [
                2
                3
              ]) q
            )
          ))
          ([
            [
              1
              2
              3
            ]
          ]);
    };
    krn-unify-records = {
      t1 =
        eq
          (K.runAll (
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
          ))
          ([
            {
              addr = "10.0.1.1";
              port = 443;
            }
            {
              addr = "10.0.1.2";
              port = 443;
            }
          ]);
      t2 = eq (K.runAll (q: K.eq { a = q; } { b = 1; })) ([ ]);
      t3 = eq (K.runAll (q: K.eq [ q 1 ] [ 2 3 ])) ([ ]);
      t4 = eq (K.runAll (
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
      )) ([ "10.0.1.1" ]); # record against record
    };
    krn-fresh-occurs = {
      t1 =
        eq
          (K.run 1 (
            q:
            K.fresh (
              { x }:
              K.eq q [
                x
                x
              ]
            )
          ))
          ([
            [
              "_.0"
              "_.0"
            ]
          ]);
      t2 = eq (K.run 1 (q: K.eq q [ q ])) ([ ]);
    };
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
      eq
        (K.run 4 (
          q:
          K.disj [
            (fives q)
            (sixes q)
          ]
        ))
        ([
          5
          6
          5
          6
        ]);
    krn-cons-unbounded = {
      t1 = eq (K.run 3 (q: K.fresh ({ x, y }: [ (K.appendo x y q) ]))) ([
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
      ]);
      t2 =
        eq
          (K.run 2 (
            q:
            K.membero q (
              K.fromList [
                "x"
                "y"
              ]
            )
          ))
          ([
            "x"
            "y"
          ]);
    };
    krn-neq-store = {
      t1 =
        eq
          (K.runAll (q: [
            (K.neq q 1)
            (K.membero q [
              1
              2
              3
            ])
          ]))
          ([
            2
            3
          ]); # =/= before the value: stored
      t2 = eq (K.runAll (
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
      )) ([ { p = 2; } ]);
      t3 = eq (K.runC 1 (q: K.fresh ({ x }: [ (K.neq q x) ]))) ([
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
      ]);
      t4 = eq (K.runAll (q: [
        (K.neq q 1)
        (K.eq q 1)
      ])) ([ ]);
    };
    krn-fd = {
      t1 =
        eq
          (K.runAll (
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
          ))
          ([
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
          ]);
      t2 =
        eq
          (K.runAll (
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
          ))
          ([
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
          ]);
      t3 =
        eq
          (K.runC 1 (q: [
            (K.infd [ q ] 2 5)
            (K.neqfd q 3)
          ]))
          ([
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
          ]);
      t4 = eq (K.runAll (q: [
        (K.infd [ q ] 1 3)
        (K.lefd 5 q)
      ])) ([ ]); # propagation alone fails it
      t5 = eq (K.runAll (q: [
        (K.infd [ q ] 1 3)
        (K.eq q 7)
      ])) ([ ]);
      t6 = eq (K.runAll (q: [
        (K.eq q 2)
        (K.infd [ q ] 1 3)
      ])) ([ 2 ]); # a bound value meets its domain
      t7 =
        eq
          (map (a: a.dom) (
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
          ))
          ([
            {
              "_.0" = [
                2
                3
                4
                5
                6
              ];
            }
          ]); # the sum is bounded
    };
    krn-neq =
      eq
        (K.runAll (
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
        ))
        ([
          [
            "x"
            "y"
          ]
          [
            "y"
            "x"
          ]
        ]);
    not-cycle-undefined =
      let
        r = logic true;
        h = "top:t/host:h";
      in
      {
        t1 = eq (map (x: "${x.aspect}@${x.scope}") r.undefined) ([
          "a@${h}"
          "b@${h}"
          "c@${h}"
          "v@${h}"
          "w@${h}/user:u"
        ]); # within and has carry it across scopes
        t2 = no (r.active.a.${h});
        t3 = no (r.active.b.${h});
        t4 = no (r.active.c.${h});
        t5 = eq (msgs r) ([ ]);
      };
    not-cycle-control =
      let
        r = logic false;
        h = "top:t/host:h";
      in
      {
        t1 = eq (r.undefined) ([ ]);
        t2 = no (r.active.a.${h});
        t3 = yes (r.active.b.${h});
        t4 = yes (r.active.c.${h});
      };
    positive-cycle-false =
      let
        r = logic true;
      in
      {
        t1 = no (r.active.p."top:t/host:h");
        t2 = no (b.any (x: x.aspect == "p" || x.aspect == "q") r.undefined);
      };
    within-has-no-cycle =
      let
        r = logic false;
      in
      {
        t1 = yes (r.active.w."top:t/host:h/user:u");
        t2 = yes (r.active.v."top:t/host:h");
      };
    diamond-memo = yes (diamond 60).active.x60."top:t/host:h";
    good-no-errors = eq (msgs good) ([ ]);
    good-persist = eq (good.reduced.persist."fleet:main/host:lb") ([ "/var/lib/motd" ]);
    good-flake = eq (good.flake.nixosConfigurations.lb) ([
      { environment.etc.motd.text = "/var/lib/motd"; }
    ]);
    neg-missing-addr = yes (has noAddr "missing addr");
    # D13: an error withholds the outputs and the reduced values (good-persist reads them on the clean fleet)
    neg-missing-addr-withholds = {
      reduced = eq noAddr.reduced null;
      flake = eq (builtins.attrNames noAddr.flake) [ "invalid-flake-errors" ];
    };
    neg-unknown-field = yes (
      has (yen.eval (fleet {
        addr = "a";
        adr = "b";
      })) "unknown field adr"
    );
    neg-bad-check = yes (
      has (yen.eval (fleet {
        addr = 1;
      })) "addr fails its check"
    );
    bad-check-reads-null = eq ((hostOf (
      yen.eval (fleet {
        addr = 1;
      })
    )).addr
    ) (null);
    two-answers = yes (
      has (yen.eval {
        imports = [
          (fleet { addr = "a"; })
          { yen.host.lb.addr = "b"; }
        ];
      }) "two answers for host.lb.addr"
    );
    same-answer-twice-ok = eq (msgs (
      yen.eval {
        imports = [
          (fleet { addr = "a"; })
          { yen.host.lb.addr = "a"; }
        ];
      }
    )) ([ ]);
    settings-value = eq ((hostOf (feat {
      settings.zfs.arcMax = 8;
    })).settings.zfs.arcMax
    ) (8);
    settings-default = eq ((hostOf (feat { })).settings.k3s.role) ("agent");
    settings-maybe-null = eq ((hostOf (feat { })).settings.zfs.arcMax) (null);
    settings-lazy = eq ((hostOf featLazy).settings.k3s.role) ("agent"); # reading zfs never forces settings.lazy's default
    settings-unknown = yes (has (feat { settings.zfz = 1; }) "unknown field settings.zfz");
    order-default = eq (ids (ordered 0)) ([
      "fleet:main"
      "fleet:main/host:a"
      "fleet:main/host:b"
      "fleet:main/host:c"
    ]);
    order-first = eq (ids (ordered (-1))) ([
      "fleet:main"
      "fleet:main/host:c"
      "fleet:main/host:a"
      "fleet:main/host:b"
    ]);
    order-bad = yes (has (ordered "x") "order is not a number");
    q5-required = yes (has (q5 ({ cluster, ... }: { })) "aspect k3s: arg `cluster` has no answer");
    q5-optional = no (
      (b.any (m: b.match ".*arg `cluster`.*" m != null) (
        msgs (
          q5 (
            {
              cluster ? null,
              ...
            }:
            { }
          )
        )
      ))
    );
    q5-emitted = yes (
      has (q5 (
        {
          cluster ? null,
          ...
        }:
        { }
      )) "no cluster: k3s off"
    );
    cycle-many-elements =
      eq
        ((yen.eval (
          { yen, ... }:
          {
            yen.kinds.top = {
              spawns = { };
              sinks.many.reduce = yen.lib.reduce.list;
            };
            yen.top.t = { };
            yen.aspects.m = {
              at = yen.kinds.top;
              cycle = _: {
                many = [
                  "a"
                  "b"
                  "c"
                ];
              };
            };
          }
        )).reduced.many."top:t"
        )
        ([
          "a"
          "b"
          "c"
        ]);
    tree-nearest = {
      t1 = eq (treeHit.reduced.seen."top:t/cluster:c1/node:n1" or null) ([ "c1" ]);
      t2 = eq (map (e: e.error) treeHit.errors) ([ ]);
    };
    tree-requests = {
      t1 = eq (treeAll.reduced.seen."top:t/cluster:c1/node:n1") ([
        {
          parent = [ "top:t/cluster:c1" ];
          none = [ ];
          kids = [
            [
              "p1"
              "p2"
            ]
          ];
          same = [ [ "top:t/cluster:c1" ] ];
          holds = [ true ];
          all = [ [ "c1" ] ];
          bad = [ ];
        }
      ]);
      t2 = eq (treeAll.errors) ([ ]);
      t3 = eq (map (e: e.code) (treeAllWith true).errors) ([ "tree-request" ]);
      t4 = eq ((treeAllWith true).reduced) (null);
    };
    # yen modules are not NixOS modules: a key yen does not read is an error, at every level
    unknown-keys =
      eq
        (map (e: { inherit (e) code from path; })
          (yen.eval {
            imports = [
              {
                options.x = 1;
                yen.kinds.host.feilds = { };
              }
              { yen.aspect.a = { }; }
            ];
          }).errors
        )
        ([
          {
            code = "unknown-key";
            from = "root/0";
            path = [ "options" ];
          }
          {
            code = "unknown-key";
            from = "root/1";
            path = [
              "yen"
              "aspect"
            ];
          }
          {
            code = "unknown-key";
            from = "root/0";
            path = [
              "yen"
              "kinds"
              "host"
              "feilds"
            ];
          }
        ]);
    # rung 1: outputs only from a clean fleet (D0)
    r1-clean-flake = eq (yen.eval (rung1 [ ])).flake { ok = true; };
    r1-violation-no-flake =
      let
        f = (yen.eval (rung1 [ sshdWeb ])).flake;
      in
      {
        t1 = eq (builtins.attrNames f) ([ "invalid-flake-errors" ]);
        t2 = eq (f.invalid-flake-errors) ({
          errors = [ ];
          violations = [
            [
              "bad"
              "no"
            ]
          ];
          incomplete = [ ];
        });
      };
    r1-error-no-flake =
      let
        f =
          (yen.eval (rung1 [
            { yen.host.web.port = 1; }
            { yen.host.web.port = 2; }
          ])).flake.invalid-flake-errors;
      in
      {
        t1 = eq (map (e: e.code) f.errors) ([ "two-answers" ]);
        t2 = eq (f.violations) ([ ]);
      };
    # D13: a fleet that is not clean gives no reduced values to build outputs from by hand
    r1-violation-no-reduced = {
      t1 = eq ((yen.eval (rung1 [ sshdWeb ])).reduced) (null);
      t2 = yes ((yen.eval (rung1 [ ])).reduced.nixos ? "top:t/host:web");
    };
    # a flake that cannot be filled is an error record, never a silent null
    flake-fill-error =
      let
        r = yen.eval {
          yen.kinds.top.spawns = { };
          yen.kinds.host = { };
          yen.top.t = { };
          yen.flake = { host, ... }: host; # no host under top: the arg has no answer
        };
      in
      {
        t1 = eq (builtins.attrNames r.flake) ([ "invalid-flake-errors" ]);
        t2 = yes (b.any (e: e.code == "arg" && e.want == "host") r.errors);
      };
    # D9: a rule never derives a fact yen extracts; it is an error, and the fleet gives no outputs
    r1-edb-head =
      let
        r = yen.eval (rung1 [
          (
            { yen, ... }:
            {
              yen.invariants.f = _: { head = yen.facts.has yen.aspects.fw "top:t/host:web"; };
            }
          )
        ]);
      in
      {
        t1 = eq (codes r) ([ "edb-head" ]);
        t2 = eq (builtins.attrNames r.flake) ([ "invalid-flake-errors" ]);
      };
    # rung 2 (vic/formally-verified.md section 3): typed facts, relations, rules as data
    # two hosts whose colon strings collide (D1): two facts, and a rule on one never fires on the other
    r2-no-collision =
      let
        r = tags (yen: {
          collide = _: {
            bad = [ ];
            pos = [ (yen.facts.host.tag "top:t/host:a:b" "1") ];
          };
        });
      in
      {
        t1 = yes (r.check.ok);
        t2 = yes (b.elem [ "val" "tag" "top:t/host:a" "b:1" ] r.facts);
        t3 = yes (b.elem [ "val" "tag" "top:t/host:a:b" "2" ] r.facts);
      };
    # the same rule with a variable binds over both hosts, and lt keeps one pair
    r2-vars =
      eq
        ((tags (yen: {
          pair =
            {
              A,
              B,
              X,
              Y,
            }:
            {
              bad = [
                A
                B
              ];
              pos = [
                (yen.facts.host.tag A X)
                (yen.facts.host.tag B Y)
                (yen.facts.lt A B)
              ];
            };
        })).check.violations
        )
        ([
          [
            "bad"
            "pair"
            "top:t/host:a"
            "top:t/host:a:b"
          ]
        ]);
    # D3: a rule is a function of its variables; an invariant written as data is an error and gives no rules
    r2-invariant-data =
      let
        r = yen.eval (rung1 [ { yen.invariants.f = [ { head = [ "bad" ]; } ]; } ]);
      in
      {
        t1 = eq (codes r) ([ "invariant-data" ]);
        t2 = eq (builtins.attrNames r.flake) ([ "invalid-flake-errors" ]);
      };
    r2-parent-fact = yes (b.elem [ "parent" "top:t/host:a" "top:t" ] (tags (_: { })).facts);
    # .21: a secret field never leaves the engine in an answer: facts, data, scopes, errors, the RDF export and the
    # seal state it by its hash, so a rule can still compare two secrets; an aspect still reads the value
    secrets-hidden =
      let
        fleet =
          extra:
          yen.eval (
            { yen, ... }:
            {
              imports = [ extra ];
              yen.kinds.top.spawns.host = _: yen.host;
              yen.kinds.host.fields.token = yen.lib.secret (yen.lib.is b.isString);
              yen.kinds.host.sinks.os = { };
              yen.top.t = { };
              yen.host.a.token = "hunter2";
              yen.aspects.login = {
                at = yen.kinds.host;
                os =
                  { host, ... }:
                  {
                    pw = host.token;
                  };
              };
            }
          );
        clean = fleet { };
        shared = fleet (
          { yen, ... }:
          {
            yen.host.b.token = "hunter2";
            yen.host.c.token = 424242;
            yen.invariants.shared-token =
              {
                A,
                B,
                X,
              }:
              {
                bad = [
                  A
                  B
                ];
                pos = [
                  (yen.facts.host.token A X)
                  (yen.facts.host.token B X)
                  (yen.facts.lt A B)
                ];
              };
          }
        );
        seen =
          r:
          b.toJSON {
            inherit (r) facts data errors;
            scopes = map (
              s:
              removeAttrs s [
                "parent"
                "up"
                "rup"
                "__here"
              ]
            ) r.scopes;
            agent = r.agent;
            export = (yen.rdf.share r).ntriples;
            seal = r.check.seal;
          };
        leaks = r: b.match ".*(hunter2|424242).*" (seen r) != null;
      in
      {
        t1 = eq (shared.check.violations) ([
          [
            "bad"
            "shared-token"
            "top:t/host:a"
            "top:t/host:b"
          ]
        ]);
        t2 = no (leaks shared);
        t3 = no (leaks clean);
        t4 = eq (clean.reduced.os."top:t/host:a") ([ { pw = "hunter2"; } ]);
      };
    r4-types =
      let
        rule =
          yen:
          { H, X }:
          {
            bad = H;
            pos = [ (yen.facts.host.tag H X) ];
            neg = [ (yen.relations.digits X) ];
          };
        run =
          rel:
          yen.eval (
            { yen, ... }:
            {
              yen.kinds.top.spawns.host = _: yen.host;
              yen.kinds.host.fields.tag = yen.lib.is (_: true);
              yen.top.t = { };
              yen.host = {
                a.tag = "b:1";
                "a:b".tag = "2";
              };
              yen.relations.digits = rel;
              yen.invariants.not-digits = rule yen;
            }
          );
        digits = s: b.match "[0-9]+" s != null;
        byType = run { type.check = digits; };
        byFn = run {
          arity = 1;
          holds = ts: digits (b.head ts);
        };
        broken = run {
          arity = 1;
          holds = ts: "yes";
        };
        bad = [
          [
            "bad"
            "not-digits"
            "top:t/host:a"
          ]
        ];
      in
      {
        t1 = eq (byType.check.violations) (bad);
        t2 = eq (byFn.check.violations) (bad);
        t3 = yes (codes broken != [ ]);
        t4 = yes (b.all (c: c == "external-not-bool") (codes broken));
        t5 = eq (builtins.attrNames broken.flake) ([ "invalid-flake-errors" ]);
      };
    # .41 (E1): a field a rule reads through an even number of `not` from `bad` gives a fact for every value, or the
    # verdict is not ok. Host a.tag is an attrset: no fact, so `bad` could be missed. Read under `not`, a missing fact
    # can only add a violation, so it is safe.
    r3-opaque =
      let
        meta =
          tagsWith
            (yen: {
              x =
                { H }:
                {
                  bad = H;
                  pos = [ (yen.facts.host.tag H "x") ];
                };
            })
            {
              a.tag = {
                x = 1;
              };
            };
        safe =
          tagsWith
            (yen: {
              x =
                { H }:
                {
                  bad = H;
                  pos = [ (yen.facts.kind yen.kinds.host H) ];
                  neg = [ (yen.facts.host.tag H "x") ];
                };
            })
            {
              a.tag = {
                x = 1;
              };
            };
      in
      {
        t1 = no (meta.check.ok);
        t2 = eq (meta.check.opaque) ([
          {
            field = "tag";
            scopes = [ "top:t/host:a" ];
          }
        ]);
        t3 = eq (safe.check.opaque) ([ ]);
      };
    # .43: where a fact comes from is its own answer, never part of the fact: one fact, two files
    r3-provenance =
      let
        r = yen.eval {
          imports = [
            portsBase
            { yen.host.a.port = 22; }
          ];
        };
        a = [
          "instance"
          "top:t/host:a"
          "host"
          "a"
        ];
        F = r.check.facts;
        hostA = {
          kind = "host";
          name = "a";
        };
      in
      {
        t1 = eq (b.length (b.filter (x: x == a) r.facts)) (1);
        # the question is a literal, by reference: identities from outside the fleet, no scope id written
        t2 = eq (b.length (r.check.from (F.instance hostA hostA))) (2);
        t3 = eq (b.length (r.check.from (F.has { aspect = "firewall"; } hostA))) (1);
        t4 = eq (r.check.from (F.edge { sink = "fw"; } hostA hostA)) ([ "aspect firewall" ]);
        list = eq (r.check.from a).code "not-a-literal";
      };
    # .42: a seal binds the verdict to its rules, facts and engine; checking it means evaluating again
    r3-seal =
      let
        p = ports { };
        seal = p.check.seal;
        tamper = seal // {
          certificate = seal.certificate // {
            false = seal.certificate.false ++ [
              {
                atom = nofw "top:t/host:b";
                stage = 0;
              }
            ];
          };
        };
      in
      {
        t1 = eq (p.check.verify seal) ({
          ok = true;
        });
        t2 = eq ((ports { yen.host.c.port = 1; }).check.verify seal) ({
          ok = false;
          why = "facts";
        });
        t3 = eq ((p.check.verify tamper).why) ("certificate");
        t4 =
          eq
            (
              (ports (
                { yen, ... }:
                {
                  yen.invariants.more = fwRules yen;
                }
              )).check.verify
              seal
            )
            ({
              ok = false;
              why = "rules";
            });
      };
    # rung 3: each verdict ships a staged certificate that the plain checker accepts, and it states the same verdict
    r3-certified =
      let
        p = (ports { }).check;
        c =
          (yen.eval (rung1 [
            {
              yen.aspects.cyc.at = [
                {
                  kind = "top";
                  name = "t";
                }
              ];
            }
          ])).check;
      in
      {
        t1 = yes (p.certified);
        t2 = yes (b.elem (nofw "top:t/host:b") (map (e: e.atom) p.certificate.true));
        t3 = yes (c.certified);
        t4 = yes (c.incomplete != [ ]);
        t5 = no ((b.elem [ "bad" "cycle" ] (map (e: e.atom) (c.certificate.true ++ c.certificate.false))));
      };
    # a derived tuple that fails its relation's check is an error (ok takes one string term here)
    relation-check =
      let
        r = tagsWith (yen: {
          r =
            { H, X }:
            {
              head = yen.relations.ok X;
              pos = [ (yen.facts.host.tag H X) ];
            };
        }) { };
      in
      eq (codes r) ([ "relation-check" ]);
    # a type whose check gives no bool (a curried gen-types check) is an error record, never a throw
    check-not-bool =
      let
        r = yen.eval (
          { yen, ... }:
          {
            yen.kinds.top.spawns.host = _: yen.host;
            yen.host.a.w = 1;
            yen.kinds.host.fields.w.check = v: (_: true);
            yen.top.t = { };
          }
        );
      in
      eq (codes r) ([ "check-not-bool" ]);
    # a literal is a reference: a string, or a hand-written list of strings, is a bad atom
    r2-string-atom = {
      t1 = eq (codes (
        rule2 (_: {
          head = "bad:x";
        })
      )) ([ "bad-atom" ]);
      t2 = eq (codes (
        rule2 (_: {
          bad = [ ];
          pos = [
            [
              "kind"
              "host"
              "top:t/host:a"
            ]
          ];
        })
      )) ([ "bad-atom" ]);
    };
    # the guards below hold for a literal built by hand, outside yen.facts and yen.relations
    r2-unknown-relation =
      let
        e =
          b.head
            (rule2 (_: {
              head = {
                atom = [
                  "okk"
                  "x"
                ];
                join = [ ];
              };
            })).errors;
      in
      {
        t1 = eq (e.code) ("unknown-relation");
        t2 = eq (e.near) ([ "ok" ]);
      };
    r2-arity = eq (codes (
      rule2 (_: {
        head = {
          atom = [ "ok" ];
          join = [ ];
        };
      })
    )) ([ "arity" ]);
    r2-unsafe = eq (codes (
      rule2 (
        { X }:
        {
          bad = X;
        }
      )
    )) ([ "unsafe-rule" ]);
    # refs in rules: a ref field joins its target's scope; negated, the join goes to pos (one instance per scope)
    refs-db-same-env =
      let
        fleet =
          extra:
          yen.eval (
            { yen, ... }:
            {
              imports = [ extra ];
              yen.kinds.top.spawns.env = _: yen.env;
              yen.kinds.env.spawns.host =
                s:
                b.removeAttrs yen.host (
                  if s.name == "lab" then
                    [
                      "db"
                      "web"
                    ]
                  else
                    [ "api" ]
                );
              yen.kinds.host.fields = {
                env = yen.kinds.env;
                db = yen.lib.maybe yen.kinds.host;
              };
              yen.top.t = { };
              yen.env.prod = { };
              yen.env.lab = { };
              yen.host.db.env = yen.env.prod;
              yen.host.web = {
                env = yen.env.prod;
                db = yen.host.db;
              };
              yen.invariants = {
                same-env =
                  {
                    H,
                    D,
                    E,
                  }:
                  {
                    bad = H;
                    pos = [
                      (yen.facts.host.db H D)
                      (yen.facts.host.env H E)
                    ];
                    neg = [ (yen.facts.host.env D E) ];
                  };
                db-set =
                  { H }:
                  {
                    bad = H;
                    pos = [ (yen.facts.host.db.set H) ];
                  };
              };
            }
          );
        lab = fleet (
          { yen, ... }:
          {
            yen.host.api = {
              env = yen.env.lab;
              db = yen.host.db;
            };
          }
        );
      in
      {
        t1 = eq (b.filter (a: b.elemAt a 1 == "same-env") (fleet { }).check.violations) ([ ]);
        t2 = eq (b.filter (a: b.elemAt a 1 == "same-env") lab.check.violations) ([
          [
            "bad"
            "same-env"
            "top:t/env:lab/host:api"
          ]
        ]);
        t3 = eq (b.filter (a: b.elemAt a 1 == "db-set") lab.check.violations) ([
          [
            "bad"
            "db-set"
            "top:t/env:lab/host:api"
          ]
          [
            "bad"
            "db-set"
            "top:t/env:prod/host:web"
          ]
        ]);
        t4 = eq (lab.errors) ([ ]);
      };
    r2-unencodable =
      let
        r = tagsWith (_: { }) { "a:b".tag = 1.5; };
      in
      {
        t1 = eq (codes r) ([ "unencodable" ]);
        t2 = eq ((b.head r.errors).path) ([ "tag" ]);
      };
    # D6: an undefined invariant is not ok
    r1-stage-incomplete =
      let
        s = r1stage {
          yen.aspects.cyc.at = [
            {
              kind = "top";
              name = "t";
            }
          ];
        } null;
      in
      {
        t1 = no (s.ok);
        t2 = eq (s.incomplete) ([
          [
            "bad"
            "cycle"
          ]
        ]);
      };
    # D7: the law cannot be switched off
    r1-no-invariants-arg = no ((b.functionArgs yen.stage) ? invariants);
    # D8: grants by path segment; added, removed and changed values all checked
    r1-grant-segment = {
      t1 = yes (
        yen.allowed r1grant {
          to = "top:t/host:web";
          sink = "fw";
        }
      );
      t2 = no (
        yen.allowed r1grant {
          to = "top:t/host:webhook";
          sink = "fw";
        }
      );
      t3 = yes (
        yen.allowed r1grant {
          to = "top:t/host:web/user:a";
          sink = "fw";
        }
      );
    };
    # D14 exact (R-yen): a change is refused only where its seeds reach through reads, once per scope (vic/r-yen.md)
    r1-grant-added = eq (r1outside (
      r1stage {
        yen.aspects.extra = {
          at = {
            kind = "host";
            name = "webhook";
          };
          fw = "x";
        };
      } r1grant
    )) ([ "top:t/host:webhook" ]);
    r1-grant-removed = eq (r1outside (r1stage { yen.host.db.bypass = true; } r1grant)) ([
      "top:t/host:db"
    ]);
    r1-grant-changed = eq (r1outside (r1stage { yen.host.db.port = 2222; } r1grant)) ([
      "top:t/host:db"
    ]);
    r1-grant-inside = eq (r1outside (r1stage { yen.host.web.port = 2222; } r1grant)) ([ ]);
    # the closure channel is closed: an element that reads another instance through `yen` is an eval error
    r1-grant-closure =
      no
        (b.tryEval (
          b.deepSeq
            (yen.eval (rung1 [
              (
                { yen, ... }:
                {
                  yen.aspects.peer = {
                    at = yen.host.db;
                    fw = "${toString yen.host.web.port}";
                  };
                }
              )
            ])).reduced.fw
            true
        )).success;
    # a read through a cycle request is an edge: a change at web reaches db, which asks for every host
    r1-grant-request = eq (r1outside (
      yen.stage {
        base = rung1 [
          (
            { yen, ... }:
            {
              yen.aspects.peer = {
                at = yen.host.db;
                cycle =
                  { tree, ... }:
                  let
                    hosts.instances = yen.kinds.host;
                  in
                  {
                    tree = [ hosts ];
                    fw = [ (toString (map (h: h.port) (b.head (tree.select hosts)))) ];
                  };
              };
            }
          )
        ];
        change.yen.host.web.port = 2222;
        grant = r1grant;
      }
    )) ([ "top:t/host:db" ]);
    r1-grant-whole = eq ((r1stage { yen.host.db.port = 2222; } (yen.grant { scopes = [ "top:t" ]; }))
      .refused
    ) ([ ]);
    r1-grant-sinks = eq (r1outside (
      r1stage { yen.host.web.port = 2222; } (
        yen.grant {
          scopes = [ "top:t" ];
          sinks = [ "fw" ];
        }
      )
    )) ([ "top:t/host:web" ]); # the port reaches web's nixos, a sink the grant does not name
    r1-grant-noop = eq ((r1stage { } r1grant).refused) ([ ]);
    # one oracle per read channel, each with the read removed as its negative control (C1-C5, vic/quorum/r3-impact.md)
    r1-grant-channels =
      let
        reach =
          extra: change:
          r1outside (
            yen.stage {
              base = rung1 (
                [
                  (
                    { yen, ... }:
                    {
                      yen.kinds.top.sinks.ports = { };
                    }
                  )
                ]
                ++ extra
              );
              inherit change;
              grant = r1grant;
            }
          );
        # every host gives its port to top: a cycle reads every sink, so a C3 or C5 reader runs without it
        up = [
          (
            { yen, ... }:
            {
              yen.aspects.up = {
                at = yen.kinds.host;
                ports = { host, ... }: host.port;
              };
            }
          )
        ];
        port.yen.host.web.port = 2222;
        at-db = el: [
          (
            { yen, ... }:
            {
              yen.aspects.reader = {
                at = yen.host.db;
              }
              // el yen;
            }
          )
        ];
        asks =
          q:
          at-db (yen: {
            cycle =
              { tree, ... }:
              let
                r = q yen;
              in
              {
                tree = [ r ];
                fw = [ (b.length (tree.select r)) ];
              };
          });
      in
      {
        # C1: a sink arg reads the reduced value at its receiver
        c1 =
          eq
            (reach (
              up
              ++ at-db (_: {
                fw = { ports, ... }: b.length ports;
              })
            ) port)
            ([
              "top:t"
              "top:t/host:db"
            ]);
        # C2, and the control of C1: a kind arg reads the nearest instance of the kind: db's own host, never web
        c2 = eq (reach (
          up
          ++ at-db (_: {
            fw = { host, ... }: host.port;
          })
        ) port) ([ "top:t" ]);
        # C3: a tree request reads what it asks
        c3 = eq (reach (asks (yen: {
          scopesOf = yen.host.web;
        })) port) ([ "top:t/host:db" ]);
        c3-control = eq (reach (asks (yen: {
          scopesOf = yen.host.webhook;
        })) port) ([ ]);
        # C4: a spawned scope is new data; it reaches what reads it
        c4 =
          eq
            (reach up {
              yen.host.mail = { };
            })
            ([
              "top:t"
              "top:t/host:mail"
            ]);
        # C5: a whole-fleet reader is reached by every change, and a change that does nothing reaches nothing
        c5 = eq (reach (asks (_: {
          graph = true;
        })) port) ([ "top:t/host:db" ]);
        c5-control = eq (reach (asks (_: {
          graph = true;
        })) { }) ([ ]);
        # C6: a spawn reads instance data, so a scope's data can change with no declaration of its own
        c6 = eq (reach [
          (
            { yen, ... }:
            {
              yen.kinds.mirror = { };
              yen.kinds.host.spawns.mirror = s: if s.name == "db" then { m.port = yen.host.web.port; } else { };
            }
          )
        ] port) ([ "top:t/host:db/mirror:m" ]);
      };
    # D9: a change never declares the law
    r1-law-change =
      eq
        (map (e: e.code)
          (r1stage {
            yen.invariants.w = _: { bad = [ ]; };
          } null).refused
        )
        ([
          "law-change"
        ]);
    # D11: a program refused before is refused again
    r1-rejected-program =
      let
        prog = [
          {
            op = "set";
            path = [
              "host"
              "db"
              "port"
            ];
            value = 2222;
          }
        ];
      in
      eq (map (e: e.code)
        (yen.program.dryRun {
          base = rung1 [ ];
          inherit prog;
          rejected = [ (b.hashString "sha256" (b.toJSON prog)) ];
        }).refused
      ) ([ "rejected" ]);
    # NixOS `config` parity (configLike): each test is one pattern a fixpoint `config` expresses
    config-no-errors = eq (msgs configLike) ([ ]);
    config-aggregate = eq (configLike.reduced.ports."fleet:main/host:b") ([ 22 ]);
    config-mkif = eq (b.sort b.lessThan configLike.reduced.ports."fleet:main/host:a") ([
      22
      80
      443
    ]);
    config-read-option = eq (configLike.reduced.firewall."fleet:main/host:a") ([
      22
      80
      443
    ]);
    config-default-from-config = eq ((hostOf configLike).fqdn) ("a.lan");
    config-lazy-chain = eq (configLike.reduced.chain."fleet:main/host:a") (20);
    config-deep-merge = eq (configLike.reduced.settings."fleet:main/host:b") ({
      a = 1;
      b.c = 2;
    });
    config-priority = {
      t1 = eq (configLike.reduced.motd."fleet:main/host:a") ("default");
      t2 = eq (configLike.reduced.motd."fleet:main/host:b") ("forced");
    };
    config-other-node = eq configLike.reduced.peers."fleet:main/host:a" { b = "10.0.0.2"; };
    # an element asks the tree for the children of its scope: a `children` request, never `yen.lib.children`
    lib-children =
      eq
        ((yen.eval (
          { yen, ... }:
          {
            yen.kinds.top = {
              spawns.host = _: {
                b = { };
                a = { };
              };
              sinks.kids = { };
            };
            yen.kinds.host = { };
            yen.top.t = { };
            yen.aspects.k = {
              at = yen.kinds.top;
              cycle =
                { tree, ... }:
                let
                  kids.children = yen.kinds.host;
                in
                {
                  tree = [ kids ];
                  kids = [ (map (c: c.name) (b.head (tree.select kids))) ];
                };
            };
          }
        )).reduced.kids."top:t"
        )
        ([
          [
            "a"
            "b"
          ]
        ]);
    lib-children-refused =
      eq
        (b.tryEval (
          b.deepSeq
            (yen.eval (
              { yen, ... }:
              {
                yen.kinds.top = {
                  spawns.host = _: {
                    b = { };
                    a = { };
                  };
                  sinks.kids = { };
                };
                yen.kinds.host = { };
                yen.top.t = { };
                yen.aspects.k = {
                  at = yen.kinds.top;
                  kids = { scope, ... }: map (c: c.name) (yen.lib.children yen.kinds.host scope);
                };
              }
            )).reduced.kids
            true
        )).success
        false;
    error-codes = {
      t1 = eq (map (e: e.code) codesFix.errors) ([
        "module"
        "spawns"
        "spawns"
        "order"
        "of"
        "bare-function"
        "arg"
        "arg"
      ]);
      t2 = eq ((b.elemAt codesFix.errors 6).want) ("host");
      t3 = eq ((b.elemAt codesFix.errors 7).error) ("aspect treeArg: arg `tree` is a cycle source");
      t4 = eq ((b.elemAt codesFix.errors 5).error) ("aspect bare: bare function: wrap it as `{ ... }:`");
    };
    unread-sink-no-error = eq (msgs (
      yen.eval {
        imports = [
          (fleet { addr = "a"; })
          { yen.aspects.motd.nixso = { }; }
        ];
      }
    )) ([ ]);
    args-flow-down = {
      addr = eq (hostOf argsDown).addr "hi";
      errors = eq (msgs argsDown) [ ];
    };
    args-missing = yes (has argsMissing "module root/0: arg `nope` has no answer");
    presence-spawns = {
      t1 = eq (ids presence) ([
        "top:t"
        "top:t/host:a"
        "top:t/host:a/svc:web"
        "top:t/host:b"
      ]);
      t2 = eq (msgs presence) ([ ]);
    };
    gap-derived-default = {
      t1 = eq ((b.head (b.filter (s: s.name == "h1") gaps.scopes)).vpn) ("vpn-h1");
      t2 = eq ((b.head (b.filter (s: s.name == "h2") gaps.scopes)).vpn) ("custom");
    };
    gap-multi-file-functions = {
      t1 = eq (gaps.reduced.nixos."fleet:main/host:h1") ([
        [ "a-h1" ]
        [ "b-h1" ]
        "marker"
      ]);
      t2 = no ((has gaps "two answers for aspects.multi.nixos"));
    };
    sink-arg-element-per-receiver = {
      t1 = eq (sinkArgs.reduced.seen."fleet:main") ([
        "prod"
        "staging"
      ]);
      t2 = eq (msgs sinkArgs) ([ ]); # a and c read one tag: once
    };
    gap-static-once-per-receiver = eq (b.length (
      b.filter (v: v == "marker") gaps.reduced.nixos."fleet:main/host:h1"
    )) (1);
    gap-bad-at = yes (has gapsBadAt "`at` holds a string, not a predicate");
    graph-edges = yes (
      b.elem {
        sink = "persist";
        from = "fleet:main/host:lb";
        to = "fleet:main/host:lb";
        origin = "aspect motd";
      } good.graph.edges
    );
    deep-1000 = eq (b.length (deep 1000).scopes) (1002);
    empty-fleet = {
      t1 = eq (msgs (yen.eval { })) ([ ]);
      t2 = eq ((yen.eval { }).scopes) ([ ]);
      t3 = eq ((yen.eval { }).flake) (null); # den-hoag empty-aspects
    };
    wide-3000 = eq (b.length (wide 3000).scopes) (3001);
  };
in
{
  inherit
    checks
    logic
    ports
    portsBase
    rung1
    yen
    ;
  # the suites, for github:denful/fastest: tests.<suite>.<test> = { expr; expected; }, run in parallel
  tests = {
    engine = checks;
    datalog = (import ./datalog.nix).tests;
    rdf = (import ./rdf.nix).tests;
    krn = (import ./krn.nix).tests;
    shacl = (import ./shacl.nix).tests;
    batteries = (import ./batteries.nix).tests;
    impact-of =
      let
        d = id: { data = id; };
        k = sink: at: { inherit sink at; };
        chain = [
          {
            out = k "s" "B";
            reads = [ (d "A") ];
          }
          {
            out = k "t" "C";
            reads = [ (k "s" "B") ];
          }
        ];
      in
      {
        # P1: a dirty token dirties every edge that reads it, transitively
        chain =
          eq
            (impactOf {
              edges = chain;
              seeds = [ (d "A") ];
            })
            ([
              (k "s" "B")
              (k "t" "C")
              (d "A")
            ]);
        # negative control: nothing reads Z, so B and C stay clean
        unread = eq (impactOf {
          edges = chain;
          seeds = [ (d "Z") ];
        }) ([ (d "Z") ]);
        # a self-loop terminates
        loop = eq (impactOf {
          edges = [
            {
              out = k "s" "B";
              reads = [ (k "s" "B") ];
            }
          ];
          seeds = [ (k "s" "B") ];
        }) ([ (k "s" "B") ]);
        # a whole-fleet reader is dirty when anything is, and only then
        whole =
          eq
            (impactOf {
              edges = [ ];
              whole = [ (k "docs" "F") ];
              seeds = [ (d "A") ];
            })
            ([
              (k "docs" "F")
              (d "A")
            ]);
        whole-control = eq (impactOf {
          edges = [ ];
          whole = [ (k "docs" "F") ];
          seeds = [ ];
        }) ([ ]);
        # scope ids hold `:`, `/` and `@`: a token is data, never parsed
        ids =
          eq
            (impactOf {
              edges = [
                {
                  out = k "out" "fleet:main";
                  reads = [ (d "fleet:main/host:db@x") ];
                }
              ];
              seeds = [ (d "fleet:main/host:db@x") ];
            })
            ([
              (k "out" "fleet:main")
              (d "fleet:main/host:db@x")
            ]);
      };
  };
}
