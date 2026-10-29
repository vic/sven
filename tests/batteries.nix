# Battery and pack oracles. Run: nix-instantiate --eval --strict tests -A failed   (expect [ ])
let
  yen = (import ../default.nix).lib;
  b = builtins;
  bat = yen.batteries;
  nixos = yen.packs.nixos;
  # the words of this fleet: no battery knows them
  fleet =
    { yen, ... }:
    {
      yen.kinds.top = {
        spawns.box = _: yen.box;
        sinks.out.reduce = yen.lib.reduce.merge;
      };
      yen.kinds.box.spawns.person = s: if s.name == "a" then { inherit (yen.person) p; } else { };
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
  # every box gives its `sys` list as output: what a battery delivered
  sysOut = bat.system {
    kind = "box";
    as = "sys";
    out = s: v: { sys.${s.name} = v; };
  };
  pooled = run [
    sysOut
    (bat.pool {
      on = "box";
      as = "names";
      into = "sys";
      set = ns: { allowed = b.concatLists ns; };
    })
    (
      { yen, ... }:
      {
        yen.aspects.x = {
          at = yen.box.a;
          names = [ "steam" ];
        };
        yen.aspects.y = {
          at = yen.person.p; # a person has no `names` sink: its names go up to its box
          names = [ "vscode" ];
        };
      }
    )
  ];
  typo = run [
    (bat.pool {
      on = "bxo";
      as = "names";
      into = "sys";
      set = ns: ns;
    })
  ];
  gatedR = run [
    sysOut
    (
      { yen, ... }:
      {
        imports = [
          (bat.gated {
            name = "label";
            at = yen.kinds.box;
            into = "sys";
            body = s: "box ${s.name}";
          })
        ];
      }
    )
  ];
  # the engine rule: a functor with `__functionArgs` is a function; without it, it is content
  functorR = run [
    sysOut
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
  hostR = run [
    sysOut
    (
      { yen, ... }:
      {
        imports = [
          (nixos.hostname {
            name = "hn";
            at = yen.box.a;
            into = "sys";
          })
        ];
      }
    )
  ];
  # a NixOS module given by the unfree pack, applied to a minimal lib
  unfreeMod =
    b.head
      (run [
        sysOut
        (nixos.unfree {
          on = "box";
          as = "unfree";
          into = "sys";
        })
        (
          { yen, ... }:
          {
            yen.aspects.u = {
              at = yen.box.a;
              unfree = [ "steam" ];
            };
          }
        )
      ]).flake.sys.a;
  pred =
    (unfreeMod {
      lib = {
        inherit (b) elem;
        getName = p: p.pname;
        flatten = b.concatLists;
      };
    }).nixpkgs.config.allowUnfreePredicate;

  checks = {
    pool =
      pooled.errors == [ ]
      &&
        pooled.flake.sys.a == [
          {
            allowed = [
              "steam"
              "vscode"
            ];
          }
        ];
    pool-only-givers = !(pooled.flake.sys ? c); # a sink with no elements gives nothing
    typo-is-violation = typo.check.violations == [ "bad:no-scope-of-kind:bxo" ] && typo.flake == null;
    gated =
      gatedR.flake.sys == {
        a = [ "box a" ];
        c = [ "box c" ];
      };
    functor = functorR.flake.sys.c == [ "at c" ];
    hostname = hostR.flake.sys.a == [ { networking.hostName = "a"; } ] && !(hostR.flake.sys ? c);
    unfree = pred { pname = "steam"; } && !(pred { pname = "zoom"; });
  };
in
{
  inherit checks;
  failed = b.filter (n: !checks.${n}) (b.attrNames checks);
}
