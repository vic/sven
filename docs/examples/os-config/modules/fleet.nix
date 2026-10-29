# Hosts build NixOS. Users live under hosts; a standalone home lives under a host too, and builds its own config.
{
  sven,
  lib,
  inputs,
  ...
}:
let
  inherit (sven.lib) same is;
in
{
  sven.kinds.fleet = {
    spawns.host = _: sven.host;
    sinks.out.reduce = sven.lib.reduce.merge;
  };
  sven.kinds.host = {
    spawns = {
      user = s: lib.filterAttrs (_: u: lib.any (same s) u.hosts) sven.user;
      home = s: lib.filterAttrs (_: h: same h.on s) sven.home;
    };
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
    sinks.osConfig.reduce = sven.lib.reduce.one; # the host's realized NixOS config
  };
  sven.kinds.user = {
    fields.hosts = is lib.isList;
    sinks.homeManager.nixos =
      { user, homeManager, ... }:
      {
        home-manager.users.${user.name}.imports = homeManager;
      };
  };
  sven.kinds.home = {
    fields = {
      user = sven.kinds.user;
      on = sven.kinds.host;
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
  sven.aspects.home-manager = {
    at = sven.lib.has sven.kinds.user;
    nixos = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
    };
  };
  sven.aspects.os-config = {
    at = sven.kinds.host;
    osConfig = { host, out, ... }: out.nixosConfigurations.${host.name}.config; # lazy: read only when a module asks
  };

  sven.fleet.main = { };
  sven.flake = { out, ... }: out;
}
