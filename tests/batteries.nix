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
        yen.kinds.person.fields.home = yen.lib.opt yen.kinds.box yen.box.a;
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

  checks = {
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
