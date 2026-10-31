# Den CI usage patterns not shown elsewhere in the fleet (vic/den-patterns.md #22 #23 #26 #48 #63 #67 #77 #103 #115 #116).
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) all within same;
  pkgs = s: inputs.nixpkgs.legacyPackages.${s};
in
{
  # #22 #23 pets and toys under hosts. A host-level cycle pairs every user with every pet (cartesian);
  # a toy-scope element reads its pet (nearest) and lands at the host (transitive).
  yen.kinds.host.spawns.pet = s: lib.filterAttrs (_: p: same p.of s) yen.pet;
  yen.kinds.pet = {
    fields.of = yen.kinds.host;
    spawns.toy = s: lib.filterAttrs (_: t: same t.of s) yen.toy;
  };
  yen.kinds.toy.fields.of = yen.kinds.pet;
  yen.pet = {
    rex.of = yen.host.stage;
    fido.of = yen.host.stage;
  };
  yen.toy = {
    ball.of = yen.pet.rex;
    bone.of = yen.pet.rex;
  };
  yen.kinds.host.sinks.pairs.reduce = yen.lib.reduce.set;
  yen.aspects.user-pet-pairs = {
    at = yen.kinds.host;
    cycle =
      { tree, ... }:
      let
        users.children = yen.kinds.user;
        pets.children = yen.kinds.pet;
      in
      {
        tree = [
          users
          pets
        ];
        pairs = lib.concatMap (u: map (p: "${u.name}-${p.name}") (lib.head (tree.select pets))) (
          lib.head (tree.select users)
        ); # one response per request
      };
  };
  yen.aspects.pet-toys = {
    at = yen.kinds.toy;
    pairs = { pet, toy, ... }: "${pet.name}/${toy.name}";
  };

  # #26 a user's `classes` choose its home systems
  yen.kinds.user.fields.classes = yen.lib.opt (yen.helpers.listOf (
    yen.helpers.enum [
      "homeManager"
      "maid"
    ]
  )) [ "homeManager" ];
  yen.user.bob.classes = [
    "homeManager"
    "maid"
  ];
  yen.aspects.maid-all = {
    at = yen.kinds.user;
    maid.".editorconfig" = "root = true";
  }; # given by every user; only users listing maid receive

  # #48 enrichment: a sink IS context. One aspect gives `isNixos`, another derives `platform` from it, content reads both.
  yen.kinds.host.sinks = {
    isNixos.reduce = yen.lib.reduce.one;
    platform.reduce = yen.lib.reduce.one;
  };
  yen.aspects.host-guards = {
    at = yen.kinds.host;
    isNixos = { host, ... }: host.system.name != "aarch64-darwin";
  };
  yen.aspects.platform-info = {
    at = yen.kinds.host;
    platform = { isNixos, ... }: if isNixos then "linux" else "other";
  };
  yen.aspects.platform-env = {
    at = yen.kinds.host;
    nixos =
      { platform, ... }:
      {
        environment.variables.PLATFORM = platform;
      };
  };

  # #63 per-host packages from USER content roll up into packages.<host system>
  yen.kinds.fleet.sinks.user-packages = {
    reduce = yen.lib.reduce.merge;
    out =
      { user-packages, ... }:
      {
        packages = lib.mapAttrs (_: ps: ps) user-packages;
      };
  };
  yen.aspects.nh-tool = {
    at = all [
      yen.kinds.user
      (within yen.kinds.host)
    ];
    user-packages =
      { host, user, ... }:
      {
        ${host.system.name}."sw-${host.name}-${user.name}" =
          (pkgs host.system.name).writeText "sw" host.name;
      };
  };

  # #67 #88 #127 host-written homeManager content for users who OPT IN; it runs at the user, with the user's own pool
  yen.kinds.user.sinks.hmvals = { };
  yen.aspects.host-aspects-opt-in.at = yen.user.alice;
  yen.aspects.user-emitter = {
    at = yen.user.alice;
    hmvals = "user";
  };
  yen.aspects.stage-home = {
    at = all [
      yen.kinds.user
      (within yen.host.stage)
      yen.aspects.host-aspects-opt-in
    ];
    homeManager =
      { hmvals, environment, ... }:
      {
        home.sessionVariables = {
          HMVALS = lib.concatStringsSep "-" hmvals;
          HOST_ENV = environment.name;
        };
      };
  };

  # #77 a pipeline stage between producers and consumers: `fw` is filtered into `fw-tcp` by a sink key
  yen.kinds.host.sinks.fw-tcp = { };
  yen.kinds.host.sinks.fw = {
    fw-tcp = { fw, ... }: lib.filter (e: e.proto == "tcp") fw;
  };
  yen.aspects.fw-ports = {
    at = yen.host.lb;
    fw = {
      port = 80;
      proto = "tcp";
    };
  };
  yen.aspects.fw-dns = {
    at = yen.host.lb;
    fw = {
      port = 53;
      proto = "udp";
    };
  };
  yen.aspects.fw-reader = {
    at = yen.host.lb;
    nixos =
      { fw-tcp, ... }:
      {
        networking.firewall.allowedTCPPorts = map (e: e.port) (lib.concatLists fw-tcp);
      };
  };

  # #103 one class forwarded into BOTH the machine's NixOS and the user's home-manager (an option both module systems have)
  yen.kinds.user.sinks.both = {
    at = within yen.helpers.linux;
    os =
      { both, ... }:
      {
        imports = both;
      };
    homeManager =
      { both, ... }:
      {
        imports = both;
      };
  };
  yen.aspects.htop-both = {
    at = yen.user.bob;
    both.programs.htop.enable = true;
  };

  # #115 broadcast: the SENDER tags who receives; readers keep what targets them, never their own
  yen.kinds.fleet.sinks.peer-dev.reduce = yen.lib.reduce.entries;
  yen.aspects.peer-dev = {
    at = all [
      yen.kinds.user
      (within yen.helpers.linux)
    ];
    peer-dev =
      { scope, ... }:
      {
        who = "${scope.name}@${scope.parent.name}";
        to = s: yen.lib.holds yen.kinds.host s;
      }; # to every host
  };
  yen.aspects.peer-dev-reader = {
    at = yen.kinds.host;
    nixos =
      { peer-dev, scope, ... }:
      {
        environment.etc."peers".text = lib.concatStringsSep "," (
          map (e: e.value.who) (lib.filter (e: e.value.to scope && e.from.parent.id != scope.id) peer-dev)
        );
      };
  };

  # #116 a host value that reads the host's OWN realized config, consumed in its users' homes
  yen.kinds.host.sinks.dev.reduce = yen.lib.reduce.one;
  yen.aspects.host-dev = {
    at = yen.host.stage;
    dev = { host, out, ... }: "h:${out.nixosConfigurations.${host.name}.config.networking.hostName}";
  };
  yen.aspects.home-dev = {
    at = all [
      yen.kinds.user
      (within yen.host.stage)
    ];
    homeManager =
      { dev, ... }:
      {
        home.sessionVariables.DEV = dev;
      };
  };
}
