# NixOS hosts hold users. A home is a standalone home-manager configuration, for a machine without NixOS.
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
    spawns = {
      host = _: yen.host;
      home = _: yen.home;
    };
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    spawns.user = s: lib.filterAttrs (_: u: lib.any (same s) u.hosts) yen.user;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.user = {
    fields.hosts = is lib.isList;
    # a user's home-manager content goes into each NixOS host it lives on
    sinks.homeManager.nixos =
      { user, homeManager, ... }:
      {
        home-manager.users.${user.name}.imports = homeManager;
      };
  };
  yen.kinds.home = {
    fields = {
      user = yen.kinds.user;
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

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
