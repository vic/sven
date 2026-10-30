# yen oracles. Run: nix-instantiate --eval --strict vic/tests -A failed   (expect [ ])
let
  yen = (import ../default.nix).lib;
  b = builtins;
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
            {
              tree = [
                {
                  category = "c";
                  nearest = yen.kinds.cluster;
                }
              ];
              errors = if tree.select "c" == [ ] then [ "no cluster: k3s off" ] else [ ];
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
          {
            tree = [
              {
                category = "c";
                nearest = yen.kinds.cluster;
              }
            ];
            seen = map (c: c.name) (tree.select "c");
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
            {
              tree = [
                {
                  category = "parent";
                  parent = true;
                }
                {
                  category = "none";
                  nearest = yen.kinds.pod;
                } # no pod above a node: no answer
                {
                  category = "kids";
                  children = yen.kinds.pod;
                }
                {
                  category = "same";
                  scopesOf = yen.cluster.c1;
                }
                {
                  category = "holds";
                  holds = yen.kinds.node;
                }
              ]
              ++ b.filter (_: bogus) [
                {
                  category = "bad";
                  bogus = true;
                }
              ];
              seen = {
                parent = map (s: s.id) (tree.select "parent");
                none = tree.select "none";
                kids = map (map (s: s.name)) (tree.select "kids");
                same = map (map (s: s.id)) (tree.select "same");
                holds = tree.select "holds";
                bad = tree.select "bad";
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
  # a variable is { var = "X"; }; every string is a constant
  v = x: { var = x; };
  nofw = id: [
    "bad"
    "no-firewall"
    id
  ];
  hasFw = id: [
    "has"
    "firewall"
    id
  ];
  cyc = [
    "has"
    "cyc"
    "top:t"
  ];
  # every host has the firewall aspect
  fwRules = [
    {
      head = [
        "bad"
        "no-firewall"
        (v "H")
      ];
      pos = [
        [
          "kind"
          "host"
          (v "H")
        ]
      ];
      neg = [
        [
          "has"
          "firewall"
          (v "H")
        ]
      ];
    }
  ];
  codes = r: map (e: e.code) r.errors;
  # rung 2 fixture: hosts `a` (tag "b:1") and `a:b` (tag "2"); `ok` is a user relation of arity 1
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
        yen.invariants.r = rules;
      }
    );
  tags = rules: tagsWith rules { };
  rule2 = r: tags [ r ];
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
            {
              head = [ "p" ];
              pos = [ cyc ];
              neg = [ [ "q" ] ];
            }
            {
              head = [ "q" ];
              pos = [ cyc ];
              neg = [ [ "p" ] ];
            }
            {
              head = [
                "bad"
                "cycle"
              ];
              pos = [ [ "p" ] ];
            }
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
  r1others = [
    "top:t"
    "top:t/host:db"
    "top:t/host:webhook"
  ];
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
      yen.invariants.fw = fwRules;
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
        yen.invariants.fw = fwRules;
      }
    );
  rec1 = r: code: b.head (b.filter (e: e.code == code) r.errors);

  checks = {
    errors-v2-check =
      let
        e = rec1 (ports { yen.host.c.port = 70000; }) "check";
      in
      e.want == "Port"
      && e.path == [ "port" ]
      && e.got == 70000
      && e.class == "fixable"
      && e.from == "host:c"
      && e.error == "port fails its check";
    errors-v2-near =
      (rec1 (ports { yen.host.b.prot = 1; }) "unknown-field").near == [ "port" ]
      && (rec1 (ports { yen.host.b.zzzzzz = 1; }) "unknown-field").near == [ ];
    errors-v2-two-answers =
      let
        e = rec1 (ports { yen.host.a.port = 23; }) "two-answers";
      in
      e.path == [
        "host"
        "a"
        "port"
      ]
      && e.got == 2;
    declared-in =
      let
        r = ports { yen.aspects.firewall.nixos = { }; };
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
      r.check.violations == [ (nofw "top:t/host:b") ]
      && r.check.incomplete == [ ]
      && !r.check.ok
      && (ports (
        { yen, ... }:
        {
          yen.aspects.fw-b = {
            at = yen.host.b;
            fw = "on";
          };
          yen.aspects.firewall.at = yen.host.b;
        }
      )).check.ok;
    invariants-incomplete =
      let
        r = ports {
          yen.relations.ok.arity = 1;
          yen.invariants.loop = [
            {
              head = loop;
              neg = [ okLoop ];
            }
            {
              head = okLoop;
              neg = [ loop ];
            }
          ];
        };
        loop = [
          "bad"
          "loop"
        ];
        okLoop = [
          "ok"
          "loop"
        ];
      in
      r.check.incomplete == [ loop ] && !b.elem loop r.check.violations && !r.check.ok;
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
            conditional = false;
          };
          tags = {
            reduce = "set";
            of = null;
            feeds = [ ];
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
      s.ok
      && s.diff.scopes.added == [ "top:t/host:c" ]
      && s.diff.scopes.removed == [ ]
      && b.isString s.sha
      && s.diff.active.added == [ "firewall@top:t/host:c" ]
      &&
        (yen.stage {
          inherit base;
          change = b.fromJSON s.render;
        }).diff == s.diff;
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
      in
      !s.ok
      && b.any (e: e.code == "two-answers") s.errors
      &&
        (b.head
          (yen.stage {
            inherit base;
            change = ch;
            rejected = [ s.sha ];
          }).refused
        ).class == "authority"
      && (
        let
          v = yen.stage {
            inherit base;
            change = yen.change.set [ "host" "c" "port" ] 1;
          };
        in
        v.violations == [ (nofw "top:t/host:c") ] && v.errors == [ ] && !v.ok
      );
    grants-narrow =
      let
        g = yen.grant {
          scopes = [ "top:t/host:a" ];
          sinks = [ "fw" ];
        };
        all' = yen.grant { scopes = [ "top:t" ]; };
        e = to: sink: { inherit to sink; };
      in
      yen.allowed g (e "top:t/host:a" "fw")
      && !yen.allowed g (e "top:t/host:b" "fw")
      && !yen.allowed g (e "top:t/host:a" "nixos")
      && yen.narrow all' g == g
      && yen.narrow g all' == g
      && (yen.narrow g (yen.grant { scopes = [ "top:t/host:b" ]; })).scopes == [ ]
      &&
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
        }).refused != [ ];
    agent-json =
      let
        a = yen.agent (ports {
          yen.host.c.port = 70000;
        });
      in
      b.fromJSON (b.toJSON a) == a
      && a.counts.scopes == 4
      && b.length a.errors == 1
      &&
        yen.jsonSafe {
          f = x: x;
          p = ./.;
        } == {
          f = "<function>";
          p = toString ./.;
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
          yen.queries = {
            portOf = { host, result, ... }: (b.head (b.filter (s: s.name == host) result.scopes)).port;
            count =
              {
                kind ? "host",
                result,
              }:
              b.length (b.filter (s: s.kind == kind) result.scopes);
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
        h = yen.history {
          url = "file://${toString ./..}";
          revs = [
            "df8ee68d5244aeca4e4bf23f1e9ecc927226d620"
          ];
          module = "tests/fixtures/history.nix";
        };
      in
      (b.elemAt h 0).changes == [ ]
      &&
        (yen.asOf {
          url = "file://${toString ./..}";
          rev = "df8ee68d5244aeca4e4bf23f1e9ecc927226d620";
          module = "tests/fixtures/history.nix";
        }).data.host.a.port == 22;
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
      yen.validAt "2026-11-15" {
        validFrom = null;
        validTo = null;
      }
      && yen.validAt "2026-11-15" {
        validFrom = "2026-01-01";
        validTo = null;
      }
      && !yen.validAt "2026-11-15" {
        validFrom = null;
        validTo = "2026-10-31";
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
      r.active.backup."top:t/host:a"
      && r.active.backup."top:t/host:b"
      && !r.active.late."top:t/host:a"
      && r.active.late."top:t/host:b";
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
      w.dropped == [ ./fixtures/without/db.nix ]
      && b.all (s: s.name != "db") w.result.scopes
      && b.any (s: s.name == "web") w.result.scopes
      &&
        (yen.without {
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
        r = yen.eval {
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
        r = yen.eval {
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
      && (yen.eval { imports = [ ./fixtures/labels/modules/base.nix ]; }).labels.web.trust == 3;
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
      b.elem [ "val" "port" "top:t/host:a" 22 ] r.facts
      && b.elem [ "ref" "peer" "top:t/host:b" "host" "a" ] r.facts
      && !(b.elem [ "ref" "peer" "top:t/host:a" "host" "b" ] r.facts);
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
          }
        );
      in
      r.check.ok
      && b.any (x: x.blocking == [ (hasFw "top:t/host:b") ]) (r.check.whyNot (nofw "top:t/host:b"))
      &&
        (r.check.proof [
          "kind"
          "host"
          "top:t/host:a"
        ]).atom == [
          "kind"
          "host"
          "top:t/host:a"
        ]
      && (ports { }).check.whyNot (nofw "top:t/host:b") == [ ];
    # D10: explanations and the verdict read one model; a fact no rule mentions is still true
    explain-same-model =
      let
        c = (ports { }).check;
      in
      !(
        (c.proof [
          "scope"
          "top:t/host:a"
        ]) ? status
      )
      &&
        c.whyNot [
          "scope"
          "top:t/host:a"
        ] == [ ];
    program-validate =
      let
        r = ports { };
        v = yen.program.validate r;
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
      ok.ok
      && ok.valid
      && ok.diff.scopes.added == [ "top:t/host:c" ]
      && b.isString ok.sha
      && !bad.ok
      && bad.violations == [ (nofw "top:t/host:c") ]
      && !(d [
        {
          op = "set";
          path = [ "hots" ];
          value = 1;
        }
      ]).valid
      &&
        b.fromJSON (
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
      (b.head ((ports { }).check.why (nofw "top:t/host:b"))).neg == [ (hasFw "top:t/host:b") ];
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
    # D13: an error withholds the outputs and the reduced values (good-persist reads them on the clean fleet)
    neg-missing-addr-withholds = noAddr.reduced == null && noAddr.flake == null;
    neg-unknown-field = has (yen.eval (fleet {
      addr = "a";
      adr = "b";
    })) "unknown field adr";
    neg-bad-check = has (yen.eval (fleet {
      addr = 1;
    })) "addr fails its check";
    bad-check-reads-null =
      (hostOf (
        yen.eval (fleet {
          addr = 1;
        })
      )).addr == null;
    two-answers = has (yen.eval {
      imports = [
        (fleet { addr = "a"; })
        { yen.host.lb.addr = "b"; }
      ];
    }) "two answers for host.lb.addr";
    same-answer-twice-ok =
      msgs (
        yen.eval {
          imports = [
            (fleet { addr = "a"; })
            { yen.host.lb.addr = "a"; }
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
      (yen.eval (
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
      )).reduced.many."top:t" == [
        "a"
        "b"
        "c"
      ];
    tree-nearest =
      treeHit.reduced.seen."top:t/cluster:c1/node:n1" or null == [ "c1" ]
      && map (e: e.error) treeHit.errors == [ ];
    tree-requests =
      treeAll.reduced.seen."top:t/cluster:c1/node:n1" == [
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
          bad = [ ];
        }
      ]
      && treeAll.errors == [ ]
      && map (e: e.code) (treeAllWith true).errors == [ "tree-request" ]
      && (treeAllWith true).reduced == null;
    # yen modules are not NixOS modules: a key yen does not read is an error, at every level
    unknown-keys =
      map (e: { inherit (e) code from path; })
        (yen.eval {
          imports = [
            {
              options.x = 1;
              yen.kinds.host.feilds = { };
            }
            { yen.aspect.a = { }; }
          ];
        }).errors == [
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
      ];
    # rung 1: outputs only from a clean fleet (D0)
    r1-clean-flake = (yen.eval (rung1 [ ])).flake == { ok = true; };
    r1-violation-no-flake =
      (yen.eval (rung1 [
        {
          yen.invariants.no = [
            {
              head = [
                "bad"
                "sshd-web"
              ];
              pos = [
                [
                  "has"
                  "sshd"
                  "top:t/host:web"
                ]
              ];
            }
          ];
        }
      ])).flake == null;
    r1-error-no-flake =
      (yen.eval (rung1 [
        { yen.host.web.port = 1; }
        { yen.host.web.port = 2; }
      ])).flake == null;
    # D13: a fleet that is not clean gives no reduced values to build outputs from by hand
    r1-violation-no-reduced =
      (yen.eval (rung1 [
        {
          yen.invariants.no = [
            {
              head = [
                "bad"
                "sshd-web"
              ];
              pos = [
                [
                  "has"
                  "sshd"
                  "top:t/host:web"
                ]
              ];
            }
          ];
        }
      ])).reduced == null
      && (yen.eval (rung1 [ ])).reduced.nixos ? "top:t/host:web";
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
      r.flake == null && b.any (e: e.code == "arg" && e.want == "host") r.errors;
    # D9: a rule never derives a fact yen extracts; it is an error, and the fleet gives no outputs
    r1-edb-head =
      let
        r = yen.eval (rung1 [
          {
            yen.invariants.f = [
              {
                head = [
                  "has"
                  "fw"
                  "top:t/host:web"
                ];
              }
            ];
          }
        ]);
      in
      codes r == [ "edb-head" ] && r.flake == null;
    # rung 2 (vic/formally-verified.md section 3): typed facts, relations, rules as data
    # two hosts whose colon strings collide (D1): two facts, and a rule on one never fires on the other
    r2-no-collision =
      let
        r = tags [
          {
            head = [
              "bad"
              "collide"
            ];
            pos = [
              [
                "val"
                "tag"
                "top:t/host:a:b"
                "1"
              ]
            ];
          }
        ];
      in
      r.check.ok
      && b.elem [ "val" "tag" "top:t/host:a" "b:1" ] r.facts
      && b.elem [ "val" "tag" "top:t/host:a:b" "2" ] r.facts;
    # the same rule with a variable binds over both hosts, and lt keeps one pair
    r2-vars =
      (tags [
        {
          head = [
            "bad"
            "pair"
            (v "A")
            (v "B")
          ];
          pos = [
            [
              "val"
              "tag"
              (v "A")
              (v "X")
            ]
            [
              "val"
              "tag"
              (v "B")
              (v "Y")
            ]
            [
              "lt"
              (v "A")
              (v "B")
            ]
          ];
        }
      ]).check.violations == [
        [
          "bad"
          "pair"
          "top:t/host:a"
          "top:t/host:a:b"
        ]
      ];
    # D3: an invariant is data; a function is an error and gives no rules
    r2-invariant-function =
      let
        r = yen.eval (rung1 [ { yen.invariants.f = _: [ ]; } ]);
      in
      codes r == [ "invariant-function" ] && r.flake == null;
    r2-parent-fact = b.elem [ "parent" "top:t/host:a" "top:t" ] (tags [ ]).facts;
    # a type whose check gives no bool (a curried gen-types check) is an error record, never a throw
    # a derived tuple that fails its relation's check is an error (ok takes one string term here)
    relation-check =
      let
        r = tagsWith [
          {
            head = [
              "ok"
              (v "X")
            ];
            pos = [
              [
                "val"
                "tag"
                (v "H")
                (v "X")
              ]
            ];
          }
        ] { };
      in
      codes r == [ "relation-check" ];
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
      codes r == [ "check-not-bool" ];
    r2-string-atom =
      codes (rule2 {
        head = "bad:x";
      }) == [ "bad-atom" ];
    r2-unknown-relation =
      let
        e =
          b.head
            (rule2 {
              head = [
                "okk"
                "x"
              ];
            }).errors;
      in
      e.code == "unknown-relation" && e.near == [ "ok" ];
    r2-arity =
      codes (rule2 {
        head = [ "ok" ];
      }) == [ "arity" ];
    r2-unsafe =
      codes (rule2 {
        head = [
          "bad"
          (v "X")
        ];
        neg = [
          [
            "has"
            "fw"
            (v "X")
          ]
        ];
      }) == [ "unsafe-rule" ];
    r2-unencodable =
      let
        r = tagsWith [ ] { "a:b".tag = 1.5; };
      in
      codes r == [ "unencodable" ] && (b.head r.errors).path == [ "tag" ];
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
      !s.ok
      &&
        s.incomplete == [
          [
            "bad"
            "cycle"
          ]
        ];
    # D7: the law cannot be switched off
    r1-no-invariants-arg = !((b.functionArgs yen.stage) ? invariants);
    # D8: grants by path segment; added, removed and changed values all checked
    r1-grant-segment =
      yen.allowed r1grant {
        to = "top:t/host:web";
        sink = "fw";
      }
      && !yen.allowed r1grant {
        to = "top:t/host:webhook";
        sink = "fw";
      }
      && yen.allowed r1grant {
        to = "top:t/host:web/user:a";
        sink = "fw";
      };
    # D14-A: every module reads the whole fleet through `yen`, so a change that declares anything can reach every
    # scope: each scope outside the grant is refused, once (vic/quorum/r3-impact.md)
    r1-grant-added =
      r1outside (
        r1stage {
          yen.aspects.extra = {
            at = {
              kind = "host";
              name = "webhook";
            };
            fw = "x";
          };
        } r1grant
      ) == r1others;
    r1-grant-removed = r1outside (r1stage { yen.host.db.bypass = true; } r1grant) == r1others;
    r1-grant-changed = r1outside (r1stage { yen.host.db.port = 2222; } r1grant) == r1others;
    r1-grant-inside = r1outside (r1stage { yen.host.web.port = 2222; } r1grant) == r1others;
    # the closure channel: db reads web's port through `yen`; a change at web reaches db
    r1-grant-closure =
      let
        s = yen.stage {
          base = rung1 [
            (
              { yen, ... }:
              {
                yen.aspects.peer = {
                  at = yen.host.db;
                  fw = "${toString yen.host.web.port}";
                };
              }
            )
          ];
          change = {
            yen.host.web.port = 2222;
          };
          grant = r1grant;
        };
      in
      b.elem "top:t/host:db" (r1outside s);
    r1-grant-whole =
      (r1stage { yen.host.db.port = 2222; } (yen.grant { scopes = [ "top:t" ]; })).refused == [ ];
    r1-grant-sinks =
      r1outside (
        r1stage { yen.host.web.port = 2222; } (
          yen.grant {
            scopes = [ "top:t" ];
            sinks = [ "fw" ];
          }
        )
      ) == [
        "top:t"
        "top:t/host:db"
        "top:t/host:web"
        "top:t/host:webhook"
      ];
    r1-grant-noop = (r1stage { } r1grant).refused == [ ];
    # D9: a change never declares the law
    r1-law-change =
      map (e: e.code)
        (r1stage {
          yen.invariants.w = [
            {
              head = [
                "bad"
                "web"
              ];
            }
          ];
        } null).refused == [
        "law-change"
      ];
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
      map (e: e.code)
        (yen.program.dryRun {
          base = rung1 [ ];
          inherit prog;
          rejected = [ (b.hashString "sha256" (b.toJSON prog)) ];
        }).refused == [ "rejected" ];
    # NixOS `config` parity (configLike): each test is one pattern a fixpoint `config` expresses
    config-no-errors = msgs configLike == [ ];
    config-aggregate = configLike.reduced.ports."fleet:main/host:b" == [ 22 ];
    config-mkif =
      b.sort b.lessThan configLike.reduced.ports."fleet:main/host:a" == [
        22
        80
        443
      ];
    config-read-option =
      configLike.reduced.firewall."fleet:main/host:a" == [
        22
        80
        443
      ];
    config-default-from-config = (hostOf configLike).fqdn == "a.lan";
    config-lazy-chain = configLike.reduced.chain."fleet:main/host:a" == 20;
    config-deep-merge =
      configLike.reduced.settings."fleet:main/host:b" == {
        a = 1;
        b.c = 2;
      };
    config-priority =
      configLike.reduced.motd."fleet:main/host:a" == "default"
      && configLike.reduced.motd."fleet:main/host:b" == "forced";
    config-other-node = configLike.reduced.peers."fleet:main/host:a" == { b = "10.0.0.2"; };
    # a plain element reads the children of its scope through `yen.lib.children`, as the `children` request does
    lib-children =
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
      )).reduced.kids."top:t" == [
        [
          "a"
          "b"
        ]
      ];
    error-codes =
      map (e: e.code) codesFix.errors == [
        "module"
        "spawns"
        "spawns"
        "order"
        "of"
        "bare-function"
        "arg"
        "arg"
      ]
      && (b.elemAt codesFix.errors 6).want == "host"
      && (b.elemAt codesFix.errors 7).error == "aspect treeArg: arg `tree` is a cycle source"
      && (b.elemAt codesFix.errors 5).error == "aspect bare: bare function: wrap it as `{ ... }:`";
    unread-sink-no-error =
      msgs (
        yen.eval {
          imports = [
            (fleet { addr = "a"; })
            { yen.aspects.motd.nixso = { }; }
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
    gap-bad-at = has gapsBadAt "`at` holds a string, not a predicate";
    graph-edges = b.elem {
      sink = "persist";
      from = "fleet:main/host:lb";
      to = "fleet:main/host:lb";
      origin = "aspect motd";
    } good.graph.edges;
    deep-1000 = b.length (deep 1000).scopes == 1002;
    empty-fleet =
      msgs (yen.eval { }) == [ ] && (yen.eval { }).scopes == [ ] && (yen.eval { }).flake == null; # den-hoag empty-aspects
    wide-3000 = b.length (wide 3000).scopes == 3001;
  };
in
{
  inherit
    checks
    logic
    ports
    portsBase
    yen
    ;
  # the lib suites live in their own files; `failed` runs them all
  failed =
    b.filter (n: !checks.${n}) (b.attrNames checks)
    ++ map (n: "datalog/${n}") (import ./datalog.nix).failed
    ++ map (n: "rdf/${n}") (import ./rdf.nix).failed
    ++ map (n: "krn/${n}") (import ./krn.nix).failed
    ++ map (n: "shacl/${n}") (import ./shacl.nix).failed;
}
