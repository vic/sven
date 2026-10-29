# Battery and sink-ref oracles. Run: nix-instantiate --eval --strict tests -A failed   (expect [ ])
let
  yen = (import ../default.nix).lib;
  b = builtins;
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

  checks = {
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
