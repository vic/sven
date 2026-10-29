# A NixOS host, and a standalone home on a machine without NixOS.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.fleet = {
    spawns = {
      host = _: yen.host;
      home = _: yen.home;
    };
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    fields.lan = lib.types.str; # the name of the LAN interface
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.home = {
    fields.system = lib.types.str;
    sinks.homeManager.out =
      { home, homeManager, ... }:
      {
        homeConfigurations.${home.name} = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.${home.system};
          modules = homeManager;
        };
      };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;

  yen.host.server.lan = "enp86s0";
  yen.home.ana.system = "x86_64-linux";
  yen.aspects.machine = {
    at = yen.host.server;
    nixos = {
      networking.hostName = "server";
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
  yen.aspects.home = {
    at = yen.home.ana;
    homeManager =
      { pkgs, ... }:
      {
        home.username = "ana";
        home.homeDirectory = "/home/ana";
        home.stateVersion = "25.05";
        nix.package = pkgs.nix;
      };
  };
}
