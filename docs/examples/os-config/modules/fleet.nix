# Hosts build NixOS. Users live under hosts; a standalone home lives under a host too, and builds its own config.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) same is;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    spawns = {
      user = s: lib.filterAttrs (_: u: lib.any (same s) u.hosts) yen.user;
      home = s: lib.filterAttrs (_: h: same h.on s) yen.home;
    };
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
    sinks.osConfig.reduce = yen.lib.reduce.one; # the host's realized NixOS config
  };
  yen.kinds.user = {
    fields.hosts = is lib.isList;
    sinks.homeManager.nixos =
      { user, homeManager, ... }:
      {
        home-manager.users.${user.name}.imports = homeManager;
      };
  };
  yen.kinds.home = {
    fields = {
      user = yen.kinds.user;
      on = yen.kinds.host;
      system = lib.types.str;
    };
    sinks.homeManager.out =
      { home, homeManager, ... }:
      {
        homeConfigurations.${home.name} = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.${home.system};
          modules = homeManager;
        };
      };
  };
  yen.aspects.home-manager = {
    at = yen.lib.has yen.kinds.user;
    nixos = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
    };
  };
  yen.aspects.os-config = {
    at = yen.kinds.host;
    osConfig = { host, out, ... }: out.nixosConfigurations.${host.name}.config; # lazy: read only when a module asks
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
