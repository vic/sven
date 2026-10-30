# Battery and sink-ref oracles. Run: nix-instantiate --eval --strict tests -A failed   (expect [ ])
let
  yen = (import ../default.nix).lib;
  b = builtins;
  nixos = yen.batteries.nixos;
  bat = yen.batteries;
  # the words of this fleet: no battery knows them. Every box gives its `sys` list as output.
  fleet =
    { yen, ... }:
    {
      yen.kinds.top = {
        spawns.box = _: yen.box;
        sinks.out.reduce = yen.lib.reduce.merge;
      };
      yen.kinds.box = {
        spawns.person = s: if s.name == "a" then { inherit (yen.person) p; } else { };
        sinks.sys.out =
          { scope, sinks, ... }:
          {
            sys.${scope.name} = sinks.${yen.kinds.box.sinks.sys.__sink};
          };
      };
      yen.kinds.person = { };
      yen.top.t = { };
      yen.box = {
        a = { };
        c = { };
      };
      yen.person.p = { };
      yen.flake = { out, ... }: out;
    };
  run = ms: yen.eval { imports = [ fleet ] ++ ms; };

  # engine: a sink carries its name; the fixed arg `sinks` reads the nearest receiver of each sink
  sinkRefs = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.names = { };
        yen.aspects.n = {
          at = yen.box.a;
          names = "steam";
        };
        yen.aspects.read = {
          at = yen.person.p; # a person has no `names` sink: `sinks.names` is its box's
          sys =
            { sinks, ... }:
            {
              seen = sinks.names;
              hasSys = sinks ? sys;
              hasOut = sinks ? out;
              name = yen.kinds.box.sinks.names.__sink;
            };
        };
      }
    )
  ];
  reserved = run [ { yen.kinds.box.sinks.sinks = { }; } ];
  # a field with the name of a scope key would be shadowed by it: an error, never a silent wrong value
  reservedField = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.fields.key = yen.lib.opt (yen.lib.is builtins.isString) "k";
      }
    )
  ];
  # the engine rule: a functor with `__functionArgs` is a function
  functorR = run [
    (
      { yen, ... }:
      {
        yen.aspects.f = {
          at = yen.box.c;
          sys = {
            __functor = _: a: "at ${a.scope.name}";
            __functionArgs.scope = false;
          };
        };
      }
    )
  ];
  # value batteries: you write the aspect and its keys
  usersR = run [
    (
      { yen, ... }:
      {
        yen.aspects.hn = {
          at = yen.box.a;
          sys = nixos.hostname;
        };
        yen.aspects.account = {
          at = yen.kinds.person; # a person has no `sys` sink: its account lands in its box's
          sys = nixos.define-user;
        };
        yen.aspects.admin = {
          at = yen.person.p;
          sys = nixos.primary-user;
        };
      }
    )
  ];
  # a battery that reads a sink takes it as a ref
  unfreeR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.unfree.sys = nixos.unfree { from = yen.kinds.box.sinks.unfree; };
        yen.aspects.u = {
          at = yen.box.a;
          unfree = [ "steam" ];
        };
        yen.aspects.v = {
          at = yen.person.p;
          unfree = [ "vscode" ];
        };
      }
    )
  ];
  pred =
    ((b.head unfreeR.flake.sys.a) {
      lib = {
        inherit (b) elem;
        getName = p: p.pname;
        flatten = b.concatLists;
      };
    }).nixpkgs.config.allowUnfreePredicate;

  # mesh: every box reads the keys of the others, never its own nor its people's
  meshR = run [
    (
      { yen, ... }:
      {
        yen.kinds.top.sinks.keys.reduce = yen.lib.reduce.entries;
        yen.aspects.key = {
          at = [
            yen.kinds.box
            yen.kinds.person
          ];
          keys = { scope, ... }: scope.name;
        };
        yen.aspects.peers = {
          at = yen.kinds.box;
          sys = bat.mesh {
            from = yen.kinds.top.sinks.keys;
            build = ks: { peers = b.sort b.lessThan ks; };
          };
        };
      }
    )
  ];
  # a top sink read back as a flake output, with a reduce under test
  topRun =
    reduce: gives:
    run [
      (
        { yen, ... }:
        {
          yen.kinds.top.sinks.got = {
            inherit reduce;
            out =
              { sinks, ... }:
              {
                got = sinks.got;
              };
          };
          yen.aspects = b.mapAttrs (n: g: {
            inherit (g) at;
            got = g.v;
          }) (gives yen);
        }
      )
    ];
  codes = r: map (e: e.code or null) r.errors;
  claimOk = topRun (bat.claim { key = v: v.addr; }) (yen: {
    a = {
      at = yen.box.a;
      v.addr = "10.0.0.1";
    };
    p = {
      at = yen.person.p;
      v.addr = "10.0.0.2";
    };
  });
  claimBad = topRun (bat.claim { key = v: v.addr; }) (yen: {
    a = {
      at = yen.box.a;
      v.addr = "10.0.0.1";
    };
    c = {
      at = yen.box.c;
      v.addr = "10.0.0.1";
    };
  });
  claimRank =
    topRun
      (bat.claim {
        key = v: v.dev;
        rank = v: v.prio;
      })
      (yen: {
        a = {
          at = yen.box.a;
          v = {
            dev = "gpu0";
            prio = 1;
          };
        };
        c = {
          at = yen.box.c;
          v = {
            dev = "gpu0";
            prio = 9;
          };
        };
      });
  sections =
    vs: yen:
    b.mapAttrs (n: v: {
      at = yen.box.a;
      inherit v;
    }) vs;
  orderedOk = topRun bat.ordered (sections {
    s1 = {
      name = "head";
      value = "H";
    };
    s2 = {
      name = "body";
      value = "B";
      after = [ "head" ];
    };
    s3 = {
      name = "foot";
      value = "F";
      after = [ "body" ];
    };
    s4 = {
      name = "toc";
      value = "T";
      after = [ "head" ];
      before = [ "body" ];
    };
  });
  orderedCycle = topRun bat.ordered (sections {
    x = {
      name = "x";
      value = 0;
      after = [ "y" ];
    };
    y = {
      name = "y";
      value = 0;
      after = [ "x" ];
    };
  });
  orderedTypo = topRun bat.ordered (sections {
    x = {
      name = "x";
      value = 0;
      after = [ "hed" ];
    };
  });

  # eval-modules: fixed modules first, then the sink's, given to lib.evalModules with specialArgs (a stub lib records them)
  evalR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.mods.sys = bat.eval-modules {
          from = yen.kinds.box.sinks.mods;
          lib.evalModules = a: { config = a; };
          modules = [ "fixed" ];
          specialArgs.x = 1;
        };
        yen.aspects.m = {
          at = yen.box.a;
          mods = "from-a";
        };
      }
    )
  ];

  mm = bat.mermaid;
  # one view: a group around a node, a shaped node, a dashed labelled edge, a quote in a label
  mmText =
    mm.flowchart
      {
        shapes = with mm.shapes; {
          db = cylinder;
        };
      }
      {
        nodes = [
          {
            id = "g";
            label = "env";
          }
          {
            id = "a";
            label = "say \"hi\"";
            group = "g";
          }
          {
            id = "d";
            label = "store";
            kind = "db";
          }
        ];
        edges = [
          {
            from = "a";
            to = "d";
            label = "writes";
            live = false;
          }
        ];
      };
  nid = id: "n${b.substring 0 10 (b.hashString "md5" id)}";
  scopesV = mm.scopes { } usersR.graph;
  routesV = mm.routes usersR.graph;

  # files.document: the texts of an ordered sink, joined, as one repo file
  docR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.doc.reduce = bat.ordered;
        yen.aspects.doc = {
          at = yen.box.a;
          sys = bat.files.document {
            from = yen.kinds.box.sinks.doc;
            path = "README.md";
          };
        };
        yen.aspects.d1 = {
          at = yen.box.a;
          doc = {
            name = "end";
            after = [ "top" ];
            value = "b";
          };
        };
        yen.aspects.d2 = {
          at = yen.person.p;
          doc = {
            name = "top";
            value = "a";
          };
        };
      }
    )
  ];

  gh = bat.github;
  ghWf = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.jobs = {
          reduce = yen.lib.reduce.merge;
          sys = gh.workflow {
            from = yen.kinds.box.sinks.jobs;
            path = "ci.yml";
            header = js: "# ${toString js}\n";
            doc.name = "t";
          };
        };
        yen.aspects.j1 = {
          at = yen.box.a;
          jobs.b.runs-on = "x";
        };
        yen.aspects.j2 = {
          at = yen.person.p;
          jobs.a.steps = [ { run = "one\ntwo\n"; } ];
        };
      }
    )
  ];

  # views: a ref field, two gates (one under a `not`), a fact test
  viewR = run [
    (
      { yen, ... }:
      {
        yen.kinds.person.fields.home = yen.lib.maybe yen.kinds.box; # a ref through maybe
        yen.aspects.g1.at = yen.kinds.box;
        yen.aspects.g2 = {
          at = yen.lib.all [
            yen.aspects.g1
            (yen.lib.not yen.aspects.g3)
          ];
          sys = "two";
        };
        yen.aspects.g3.at = s: s.name == "c";
        yen.aspects.g4.at = yen.aspects.g2; # makes g2 a gate: its own `at` is drawn
        yen.aspects.views = {
          at = yen.top.t;
          out.views = {
            kinds = mm.kinds yen.kinds;
            gates = mm.gates yen.aspects;
          };
        };
      }
    )
  ];
  inherit (viewR.flake.views) kinds gates;
  kindsV = kinds;
  gatesV = gates;
  routingV = mm.routing viewR.graph;
  sinksV = mm.sinks {
    inherit (viewR) schema graph;
  };
  grouped = mm.scopes {
    keep = s: s.kind != "top";
    label = s: s.name;
    group = s: if s.kind == "person" then "top:t/box:a" else null;
  } viewR.graph;

  linkRun =
    needle:
    topRun (bat.docs.links { root = ./.; }) (yen: {
      l = {
        at = yen.box.a;
        v = {
          name = "dl";
          file = "datalog.nix";
          inherit needle;
          text = "datalog";
        };
      };
    });
  vocabRun =
    lines:
    run [
      (
        { yen, ... }:
        {
          yen.aspects.vocab = {
            at = yen.top.t;
            errors = bat.docs.vocabulary {
              what = "kinds";
              names = builtins.attrNames yen.kinds;
              inherit lines;
            };
          };
        }
      )
    ];
  allKinds = {
    top = "root";
    box = "a box";
    person = "a person";
  };

  # devshells with stub builders: they return what they get
  shellRun =
    wrap: sys:
    run [
      (
        { yen, ... }:
        {
          yen.kinds.box.sinks.cmds.sys = sys yen;
          yen.aspects.c1 = {
            at = yen.box.a;
            cmds = wrap { name = "one"; };
          };
          yen.aspects.c2 = {
            at = yen.person.p;
            cmds = wrap {
              name = "two";
              packages = [ "pk" ];
              shellHook = "h;";
            };
          };
        }
      )
    ];
  numtideR = shellRun (c: [ c ]) (
    yen:
    bat.devshell.numtide {
      from = yen.kinds.box.sinks.cmds;
      devshell.legacyPackages.sx.mkShell = a: a;
      systems = [ "sx" ];
      pkgsOf = s: { tool = s; };
      name = "n";
      packages = pkgs: [ pkgs.tool ];
    }
  );
  mkshellR = shellRun (c: c) (
    yen:
    bat.devshell.mkshell {
      from = yen.kinds.box.sinks.cmds;
      pkgsOf = s: { mkShell = a: a // { on = s.name; }; };
    }
  );

  # flake-file.write with a stub lib: the merged sink is one module after flake-file's own
  ffR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.ff = {
          reduce = yen.lib.reduce.merge;
          sys = bat.flake-file.write {
            from = yen.kinds.box.sinks.ff;
            lib.evalModules = a: {
              config.flake-file = {
                apps.write-flake = p: a.modules;
                check-flake-file = p: p.stdenv.hostPlatform.system;
              };
            };
            inputs.flake-file.flakeModules.flake = "ffm";
            pkgs.stdenv.hostPlatform.system = "sx";
            modules = [ "extra" ];
          };
        };
        yen.aspects.f1 = {
          at = yen.box.a;
          ff.inputs.x.url = "u1";
        };
        yen.aspects.f2 = {
          at = yen.person.p;
          ff.inputs.y.url = "u2";
        };
      }
    )
  ];

  jsonR = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.jobs = {
          reduce = yen.lib.reduce.merge;
          sys = bat.files.json {
            from = yen.kinds.box.sinks.jobs;
            path = "ci.json";
            value = builtins.attrNames;
          };
        };
        yen.aspects.j1 = {
          at = yen.box.a;
          jobs.b = 1;
        };
        yen.aspects.j2 = {
          at = yen.person.p;
          jobs.a = 2;
        };
      }
    )
  ];

  # clan batteries as plain functions of data
  cl = bat.clan;
  clServices = {
    db = {
      roles.server.interface.port = {
        type = {
          check = b.isInt;
          description = "int";
        };
        default = 5432;
      };
      roles.client = { };
      constraints = {
        roles.server = {
          min = 1;
          max = 1;
        };
        maxInstances = 1;
      };
      exports = [ "endpoint" ];
    };
  };
  clMachines = [
    {
      name = "a";
      labels = [ "dbs" ];
    }
    {
      name = "c";
      labels = [ ];
    }
  ];
  clInstances = {
    main = {
      module = "db";
      roles.server = {
        tags = [ "dbs" ];
        machines.a.settings.port = 1;
      };
      roles.client.machines.c = { };
    };
  };
  clContract =
    instances:
    cl.contract {
      inherit instances;
      services = clServices;
      machines = clMachines;
    };

  # clan vars batteries as plain functions
  gen =
    xs:
    cl.generators { machineOf = s: s; } (
      map (x: {
        from.name = x.m;
        value = x.v;
      }) xs
    );
  gens = gen [
    {
      m = "a";
      v = {
        name = "ssh";
        files.key.secret = true;
        files."key.pub".secret = false;
      };
    }
    {
      m = "c";
      v = {
        name = "ssh";
        files.key.secret = true;
      };
    }
    {
      m = "a";
      v = {
        name = "wifi";
        share = true;
        files.pw = { };
        files.ca = {
          deploy = false;
        };
      };
    }
    {
      m = "c";
      v = {
        name = "wifi";
        share = true;
        files.pw = { };
      };
    }
    {
      m = "a";
      v = {
        name = "borg";
        dependencies = [ "ssh" ];
        files.pass.neededFor = "users";
      };
    }
    {
      m = "a";
      v = null;
    }
  ];
  badDeps = gen [
    {
      m = "c";
      v = {
        name = "borg";
        dependencies = [ "nope" ];
      };
    }
  ];
  plan =
    (cl.vars-plan {
      from.__sink = "g";
      machines = [ "a" ];
      recipientsOf = m: [ "r-${m}" ];
    } { sinks.g = gens.value; }).varsPlan.a;
  secretReads =
    cl.secret-reads
      {
        from.__sink = "g";
        reads.__sink = "r";
      }
      {
        sinks = {
          g = gens.value;
          r = [
            {
              value = {
                machine = "a";
                generator = "ssh";
                file = "key";
              };
            }
            {
              value = {
                machine = "a";
                generator = "ssh";
                file = "key.pub";
              };
            }
          ];
        };
      };
  pub = cl.public-value { root = ./fixtures/vars; };

  # secretspec through a claim sink: one secret per (profile, name)
  specRun =
    extra:
    run [
      (
        { yen, ... }:
        {
          yen.kinds.box.sinks.secrets = {
            reduce = bat.claim { key = s: "${s.profile or "default"}/${s.name}"; };
            sys = bat.secretspec.toml {
              from = yen.kinds.box.sinks.secrets;
              project.name = "app";
              profiles.dev.defaults."inherit" = false;
            };
          };
          yen.aspects.s1 = {
            at = yen.box.a;
            secrets = {
              name = "DB_URL";
              description = "db";
            };
          };
          yen.aspects.s2 = {
            at = yen.person.p;
            secrets = {
              name = "DB_URL";
              profile = "dev";
              default = "sqlite://x";
            };
          };
        }
      )
      extra
    ];
  cachesRun = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks.caches = {
          sys = bat.cachix.caches { from = yen.kinds.box.sinks.caches; };
        };
        yen.aspects.c1 = {
          at = yen.box.a;
          caches = {
            name = "vix";
            publicKey = "vix.cachix.org-1:K";
          };
        };
        yen.aspects.c2 = {
          at = yen.person.p;
          caches = {
            name = "own";
            url = "https://cache.example";
            publicKey = "own-1:K";
          };
        };
        yen.aspects.c3 = {
          at = yen.box.a;
          caches = {
            name = "vix";
            publicKey = "vix.cachix.org-1:K";
          };
        };
      }
    )
  ];

  # NixOS batteries called directly: yen args, then NixOS module args
  sc = name: {
    inherit name;
    id = "f/host:${name}";
  };
  ent = name: v: {
    from.id = "f/host:${name}";
    value = v;
  };
  peers = [
    (ent "a" {
      name = "a";
      addr = "10.0.0.1";
      key = "ka";
    })
    (ent "c" {
      name = "c";
      addr = "10.0.0.2";
    })
  ];
  builders = [
    (ent "a" {
      hostName = "a";
      system = "x86_64-linux";
    })
    (ent "c" {
      hostName = "c";
      system = "aarch64-linux";
    })
    (ent "d" {
      hostName = "d";
      system = "x86_64-linux";
    })
  ];

  checks = {
    configurations =
      bat.configurations
        {
          from.__sink = "m";
          output = "xConfigurations";
          build = s: ms: {
            inherit (s) name;
            inherit ms;
          };
        }
        {
          scope.name = "h";
          sinks.m = [ "a" ];
        } == {
        xConfigurations.h = {
          name = "h";
          ms = [ "a" ];
        };
      };
    darwin-system =
      (bat.darwin.system
        {
          from.__sink = "d";
          darwinSystem = m: a: a // { by = m.name; };
          system = m: m.sys;
        }
        {
          scope = {
            name = "mac";
            sys = "aarch64-darwin";
          };
          sinks.d = [ "x" ];
        }
      ).darwinConfigurations.mac == {
        system = "aarch64-darwin";
        modules = [ "x" ];
        by = "mac";
      };
    darwin-primary-user =
      (bat.darwin.primary-user { user = m: m.o; } { scope.o.name = "ana"; }).system.primaryUser == "ana"
      && (bat.darwin.primary-user { user = _: null; } { scope = { }; }).system.primaryUser == "root";
    darwin-homebrew =
      (bat.darwin.homebrew { from.__sink = "b"; } {
        sinks.b = [
          { casks = [ "a" ]; }
          {
            casks = [ "a" ];
            brews = [ "jq" ];
            masApps.X = 1;
          }
        ];
      }).homebrew == {
        enable = true;
        casks = [ "a" ];
        brews = [ "jq" ];
        masApps.X = 1;
      };
    home-manager-system =
      (bat.home-manager.system
        {
          from.__sink = "h";
          homeManagerConfiguration = _: a: a;
          pkgs = h: "pkgs-${h.name}";
        }
        {
          scope.name = "ana";
          sinks.h = [ "m" ];
        }
      ).homeConfigurations.ana == {
        pkgs = "pkgs-ana";
        modules = [ "m" ];
      };
    home-manager-into-host =
      bat.home-manager.into-host { from.__sink = "h"; } {
        scope.name = "ana";
        sinks.h = [ "m" ];
      } == {
        home-manager.users.ana.imports = [ "m" ];
      };
    droid =
      (bat.droid.system
        {
          from.__sink = "d";
          nixOnDroidConfiguration = a: a;
          pkgs = _: "p";
        }
        {
          scope.name = "pixel";
          sinks.d = [ "m" ];
        }
      ).nixOnDroidConfigurations.pixel.modules == [ "m" ]
      &&
        bat.droid.home { from.__sink = "h"; } { sinks.h = [ "hm" ]; } == {
          home-manager.config.imports = [ "hm" ];
        };
    microvm-guest =
      bat.microvm.guest
        {
          from.__sink = "n";
          pkgs = g: "p-${g.name}";
        }
        {
          scope.name = "ci";
          sinks.n = [ "m" ];
        } == {
        microvm.vms.ci = {
          pkgs = "p-ci";
          config.imports = [ "m" ];
        };
      };
    exports-modules =
      bat.exports.modules
        {
          from.__sink = "os";
          output = "homeModules";
        }
        {
          scope.name = "base";
          sinks.os = [ "m" ];
        } == {
        homeModules.base.imports = [ "m" ];
      };
    docs-table =
      bat.docs.table
        [ "A" "B" ]
        [
          [
            "1"
            "2"
          ]
        ] == "| A | B |\n|---|---|\n| 1 | 2 |";
    docs-kinds =
      bat.docs.kinds
        {
          box = {
            fields.x = 1;
            sinks.s = { };
          };
        }
        {
          scopes = [
            { kind = "box"; }
            { kind = "box"; }
          ];
        }
      == "| Kind | Fields | Spawns | Sinks | Scopes |\n|---|---|---|---|---|\n| `box` | `x` |  | `s` | 2 |";
    docs-templates =
      b.attrNames (
        bat.docs.templates {
          root = ../docs/examples;
          description = _: "";
        }
      ) != [ ]
      && !(bat.docs.templates {
        root = ../docs/examples;
        description = _: "";
      })
        ? about; # docs/examples/about has no flake.nix
    files-comment =
      bat.files.comment "README.md" "x" == "<!-- x -->\n"
      && bat.files.comment "a/ci.yml" "x" == "# x\n"
      && bat.files.comment "main.rs" "x" == "// x\n"
      && bat.files.comment "ci.json" "x" == "";
    nixos-user-shell =
      (nixos.user-shell { shell = u: u.sh; } {
        scope = sc "ana" // {
          sh = "fish";
        };
      } { pkgs.fish = "F"; }) == {
        users.users.ana.shell = "F";
        programs.fish.enable = true;
      }
      && !(
        (nixos.user-shell { shell = _: "bash"; } { scope = sc "bob"; } { pkgs.bash = "B"; }) ? programs
      );
    nixos-autologin =
      nixos.autologin { user = h: h.u; } {
        scope = sc "h" // {
          u = {
            name = "ana";
          };
        };
      } == {
        services.getty.autologinUser = "ana";
      }
      && nixos.autologin { user = _: null; } { scope = sc "h"; } == { };
    nixos-firewall =
      nixos.firewall { from.__sink = "p"; } {
        sinks.p = [
          22
          { udp = [ 53 ]; }
          {
            tcp = [
              22
              80
            ];
          }
        ];
      } == {
        networking.firewall = {
          allowedTCPPorts = [
            22
            80
          ];
          allowedUDPPorts = [ 53 ];
        };
      };
    nixos-persist =
      nixos.persist { from.__sink = "p"; } {
        sinks.p = [
          "/var/lib/x"
          { files = [ "/etc/machine-id" ]; }
          "/var/lib/x"
        ];
      } == {
        environment.persistence."/persist" = {
          directories = [ "/var/lib/x" ];
          files = [ "/etc/machine-id" ];
        };
      };
    nixos-hosts =
      nixos.hosts { from.__sink = "p"; } {
        scope = sc "d"; # sees both; only a has a key
        sinks.p = peers;
      } == {
        networking.hosts = {
          "10.0.0.1" = [ "a" ];
          "10.0.0.2" = [ "c" ];
        };
        programs.ssh.knownHosts.a = {
          hostNames = [
            "a"
            "10.0.0.1"
          ];
          publicKey = "ka";
        };
      };
    nixos-remote-builders =
      map (m: m.hostName)
        (nixos.remote-builders
          {
            from.__sink = "b";
            systemOf = _: "x86_64-linux";
          }
          {
            scope = sc "a";
            sinks.b = builders;
          }
        ).nix.buildMachines == [ "d" ];
    nixos-facter =
      nixos.facter {
        report = h: "/r/${h.name}.json";
        module = "M";
      } { scope = sc "h"; } == {
        hardware.facter.reportPath = "/r/h.json";
        imports = [ "M" ];
      };
    files-toml =
      bat.files.toml { } {
        p.name = "a b";
        p."x.y" = [
          1
          true
        ];
        t.k.inline = {
          a = 1;
        };
      } == "[p]\nname = \"a b\"\n\"x.y\" = [1, true]\n\n[t.k]\ninline = { a = 1 }\n";
    secretspec-toml =
      (specRun { }).flake.sys.a == [
        {
          files.file."secretspec.toml".text =
            "[profiles.default]\nDB_URL = { description = \"db\" }\n\n[profiles.dev]\nDB_URL = { default = \"sqlite://x\" }\ndefaults = { inherit = false }\n\n[project]\nname = \"app\"\n";
        }
      ];
    secretspec-twice =
      codes (
        specRun (
          { yen, ... }: {
            yen.aspects.s3 = {
              at = yen.person.p; # another scope than s1: two owners
              secrets.name = "DB_URL";
            };
          }
        )
      ) == [ "claim" ];
    cachix-caches =
      cachesRun.flake.sys.a == [
        {
          nix.settings = {
            substituters = [
              "https://vix.cachix.org"
              "https://cache.example"
            ];
            trusted-public-keys = [
              "vix.cachix.org-1:K"
              "own-1:K"
            ];
          };
        }
      ];
    cachix-flake-config =
      (bat.cachix.flake-config { from.__sink = "c"; } {
        sinks.c = [
          {
            name = "vix";
            publicKey = "k";
          }
        ];
      }).nixConfig == {
        extra-substituters = [ "https://vix.cachix.org" ];
        extra-trusted-public-keys = [ "k" ];
      };
    cachix-action = (bat.cachix.action { name = "vix"; }).uses == "cachix/cachix-action@v17";
    clan-generators =
      b.attrNames gens.value == [
        "borg@a"
        "ssh@a"
        "ssh@c"
        "wifi"
      ]
      &&
        gens.value.wifi.machines == [
          "a"
          "c"
        ]
      && gens.errors == [ ];
    clan-generators-dependency =
      map (e: e.error) badDeps.errors == [ "vars: generator borg@c depends on nope, which c has not" ];
    clan-vars-plan =
      map (g: g.name) plan.order == [
        "ssh"
        "borg"
        "wifi"
      ]
      &&
        map (f: f.path) plan.files == [
          "/run/secrets-for-users/vars/borg/pass"
          "/run/secrets/vars/ssh/key"
          "/run/secrets/vars/wifi/pw"
        ]
      && plan.recipients == [ "r-a" ];
    clan-secret-reads = secretReads == [ "vars: a reads ssh/key, a secret file" ];
    clan-public-value =
      pub "lb" "openssh" "key.pub" "absent" == "ssh-ed25519 PUB"
      && pub "lb" "openssh" "nope" "absent" == "absent";
    clan-members-by-tag =
      b.attrNames (
        cl.members {
          instances.t = {
            module = "db";
            roles.server.tags = [ "dbs" ];
          };
          services = clServices;
        } (b.head clMachines)
      ) == [ "t.server" ];
    clan-members =
      cl.members {
        instances = clInstances;
        services = clServices;
      } (b.head clMachines) == {
        "main.server" = {
          instance = "main";
          service = "db";
          role = "server";
          settings.port = 1;
          extraModules = [ ];
        };
      };
    clan-contract-ok = clContract clInstances == [ ];
    clan-contract-min =
      clContract {
        x = {
          module = "db";
          roles.server.tags = [ "none" ];
        };
      } == [ "clan: instance x role server: 0 machines, at least 1" ];
    clan-contract-unknown-role =
      clContract {
        x = {
          module = "db";
          roles.server.machines.a = { };
          roles.ghost.machines.a = { };
        };
      } == [ "clan: instance x: service db has no role ghost" ];
    clan-contract-max-instances =
      b.length (
        clContract (
          clInstances
          // {
            two = clInstances.main;
          }
        )
      ) == 2;
    clan-unknown-tags =
      cl.unknown-tags {
        instances = clInstances // {
          t = {
            module = "db";
            roles.client.tags = [ "nope" ];
          };
        };
        machines = clMachines;
      } == [ "clan: instance t role client: tag nope matches no machine" ];
    clan-exports =
      let
        member = name: {
          id = "m:${name}";
          service = "db";
          instance = "main";
          role = "server";
          parent.name = name;
        };
        r =
          cl.exports
            {
              services = clServices;
              isMember = s: s ? service;
            }
            [
              {
                from = member "a";
                value.endpoint = "a:1";
              }
              {
                from = member "c";
                value.secret = "x";
              }
              {
                from.id = "fleet";
                value = {
                  service = "db";
                  instance = "main";
                  role = "server";
                  machine = "a";
                  value.endpoint = "over";
                };
              }
            ];
      in
      (b.head r.value).value.endpoint == "over"
      && map (e: e.error) r.errors == [ "clan: db:main:server:c: service db does not export secret" ];
    maybe-ref-schema = viewR.schema.kinds.person.fields.home.ref or null == "box";
    files-json = jsonR.flake.sys.a == [ { files.file."ci.json".text = "[\"a\",\"b\"]\n"; } ];
    flake-file-write =
      ffR.flake.sys.a == [
        {
          packages.sx.write-flake = [
            "ffm"
            {
              flake-file.inputs = {
                x.url = "u1";
                y.url = "u2";
              };
            }
            "extra"
          ];
          checks.sx.flake-file = "sx";
        }
      ];
    devshell-numtide =
      numtideR.flake.sys.a == [
        {
          devShells.sx.default = {
            name = "n";
            packages = [ "sx" ];
            commands = [
              { name = "one"; }
              {
                name = "two";
                packages = [ "pk" ];
                shellHook = "h;";
              }
            ];
          };
        }
      ];
    devshell-mkshell =
      mkshellR.flake.sys.a == [
        {
          devShells.a.default = {
            packages = [ "pk" ];
            shellHook = "h;";
            on = "a";
          };
        }
      ];
    docs-links = (linkRun "datalog oracles").flake.got == { dl = "[`datalog`](datalog.nix#L1)"; };
    docs-links-gone = codes (linkRun "zz-none-yen") == [ "link-gone" ];
    docs-vocabulary = (vocabRun allKinds).errors == [ ];
    docs-vocabulary-drift =
      b.sort b.lessThan (codes (vocabRun (b.removeAttrs allKinds [ "box" ] // { ghost = "x"; }))) == [
        "doc-missing"
        "doc-stale"
      ];
    mermaid-kinds =
      b.elem {
        from = "k:box";
        to = "k:person";
      } kindsV.edges
      && b.elem {
        from = "k:person";
        to = "k:box";
        label = "home";
        live = false;
      } kindsV.edges;
    mermaid-gates =
      b.elem {
        from = "a:g1";
        to = "a:g2";
        label = "";
        live = true;
      } gatesV.edges
      && b.elem {
        from = "a:g3";
        to = "a:g2";
        label = "not";
        live = false;
      } gatesV.edges
      && b.elem {
        from = "f:g3";
        to = "a:g3";
        label = "";
        live = true;
      } gatesV.edges;
    mermaid-routing =
      b.elem {
        from = "s:sys";
        to = "k:box";
        label = "1";
      } routingV.edges
      && b.elem {
        from = "k:box";
        to = "s:sys";
        label = "1";
      } routingV.edges;
    mermaid-sinks = b.elem {
      from = "sink:sys";
      to = "flake";
      label = "a";
    } sinksV.edges;
    mermaid-scopes-options =
      !(b.any (n: n.id == "top:t") grouped.nodes)
      && b.elem {
        id = "top:t/box:a/person:p";
        kind = "person";
        label = "p";
        group = "top:t/box:a";
      } grouped.nodes
      && grouped.edges == [ ];
    github-yaml =
      gh.yaml {
        k = [
          "v"
          { x = { }; }
        ];
        s = "a\nb\n";
        "q:" = true;
      } == "\"k\":\n  - \"v\"\n  -\n    \"x\": {}\n\"q:\": true\n\"s\": |\n  a\n  b\n";
    github-workflow =
      ghWf.flake.sys.a == [
        {
          files.file."ci.yml".text =
            "# a b\n\"jobs\":\n  \"a\":\n    \"steps\":\n      -\n        \"run\": |\n          one\n          two\n  \"b\":\n    \"runs-on\": \"x\"\n\"name\": \"t\"\n";
        }
      ];
    files-document = docR.flake.sys.a == [ { files.file."README.md".text = "a\nb"; } ];
    mermaid-flowchart =
      mmText == b.concatStringsSep "\n" [
        "flowchart LR"
        "  subgraph ${nid "g"} [\"env\"]"
        "    ${nid "a"}[\"say 'hi'\"]"
        "  end"
        "  ${nid "d"}[(\"store\")]"
        "  ${nid "a"} -.->|\"writes\"| ${nid "d"}"
      ];
    mermaid-scopes =
      b.length scopesV.nodes == b.length usersR.graph.scopes
      && b.elem {
        from = "top:t";
        to = "top:t/box:a";
      } scopesV.edges;
    mermaid-routes =
      b.all (e: e.from != e.to) routesV.edges
      && b.elem {
        from = "top:t/box:a/person:p";
        to = "top:t/box:a";
        label = "sys";
      } routesV.edges;
    eval-modules =
      evalR.flake.sys.a == [
        {
          modules = [
            "fixed"
            "from-a"
          ];
          specialArgs.x = 1;
        }
      ];
    mesh =
      meshR.errors == [ ]
      &&
        meshR.flake.sys == {
          a = [ { peers = [ "c" ]; } ];
          c = [
            {
              peers = [
                "a"
                "p"
              ];
            }
          ];
        };
    claim =
      claimOk.flake.got == {
        "10.0.0.1".addr = "10.0.0.1";
        "10.0.0.2".addr = "10.0.0.2";
      };
    claim-two-owners = codes claimBad == [ "claim" ] && claimBad.flake == null;
    claim-rank = claimRank.errors == [ ] && claimRank.flake.got.gpu0.prio == 9;
    ordered =
      orderedOk.flake.got == [
        "H"
        "T"
        "B"
        "F"
      ];
    ordered-cycle = codes orderedCycle == [ "ordered-cycle" ];
    ordered-unknown = codes orderedTypo == [ "ordered-unknown" ];
    sink-name-and-sinks-arg =
      sinkRefs.errors == [ ]
      &&
        sinkRefs.flake.sys.a == [
          {
            seen = [ "steam" ];
            hasSys = true;
            hasOut = true;
            name = "names";
          }
        ];
    sink-named-sinks = b.any (e: (e.code or null) == "reserved") reserved.errors;
    field-named-key = b.any (
      e:
      (e.code or null) == "reserved"
      &&
        e.path or null == [
          "box"
          "key"
        ]
    ) reservedField.errors;
    functor = functorR.flake.sys.c == [ "at c" ];
    users =
      usersR.errors == [ ]
      &&
        usersR.flake.sys.a == [
          { networking.hostName = "a"; }
          {
            users.users.p = {
              isNormalUser = true;
              home = "/home/p";
            };
          }
          {
            users.users.p.extraGroups = [
              "wheel"
              "networkmanager"
            ];
          }
        ]
      && !(usersR.flake.sys ? c);
    unfree =
      unfreeR.errors == [ ]
      && pred { pname = "steam"; }
      && pred { pname = "vscode"; }
      && !(pred { pname = "zoom"; })
      && !(unfreeR.flake.sys ? c); # a sink with no elements gives nothing
  };
in
{
  inherit checks;
  failed = b.filter (n: !checks.${n}) (b.attrNames checks);
}
