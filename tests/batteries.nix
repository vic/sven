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

  checks = {
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
