# Battery oracles. Run: nix-instantiate --eval --strict tests -A failed   (expect [ ])
let
  yen = (import ../default.nix).lib;
  b = builtins;
  bat = yen.batteries;
  nixos = yen.batteries.nixos;
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
        sinks = bat.system {
          as = "sys";
          out = s: v: { sys.${s.name} = v; };
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
  pooled = run [
    (
      { yen, ... }:
      {
        yen.kinds.box.sinks = bat.pool {
          as = "names";
          into = "sys";
          set = ns: { allowed = b.concatLists ns; };
        };
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
  gatedR = run [
    (
      { yen, ... }:
      {
        yen.aspects.label = bat.gated {
          at = yen.kinds.box;
          into = "sys";
          body = s: "box ${s.name}";
        };
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
  hostR = run [
    (
      { yen, ... }:
      {
        yen.aspects.hn = nixos.hostname {
          at = yen.box.a;
          into = "sys";
        };
      }
    )
  ];
  # a person's account lands in its box's `sys`: the person has no `sys` sink
  usersR = run [
    (
      { yen, ... }:
      {
        yen.aspects.account = nixos.define-user {
          at = yen.kinds.person;
          into = "sys";
        };
        yen.aspects.admin = nixos.primary-user {
          at = yen.person.p;
          into = "sys";
        };
      }
    )
  ];
  # a NixOS module given by the unfree battery, applied to a minimal lib
  unfreeMod =
    b.head
      (run [
        (
          { yen, ... }:
          {
            yen.kinds.box.sinks = nixos.unfree {
              as = "unfree";
              into = "sys";
            };
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
    gated =
      gatedR.flake.sys == {
        a = [ "box a" ];
        c = [ "box c" ];
      };
    functor = functorR.flake.sys.c == [ "at c" ];
    hostname = hostR.flake.sys.a == [ { networking.hostName = "a"; } ] && !(hostR.flake.sys ? c);
    users =
      usersR.flake.sys.a == [
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
    unfree = pred { pname = "steam"; } && !(pred { pname = "zoom"; });
  };
in
{
  inherit checks;
  failed = b.filter (n: !checks.${n}) (b.attrNames checks);
}
