# Each host carries its public facts as fields. Every module can read every host: they are data, not NixOS configs.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  str = lib.types.str;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    fields = {
      sshKey = str;
      wgKey = str;
      wgIp = str;
    };
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;

  yen.host = {
    nas = {
      sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINas";
      wgKey = "nas0wgPublicKey0000000000000000000000000000=";
      wgIp = "10.9.0.1";
    };
    desk = {
      sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDesk";
      wgKey = "desk0wgPublicKey000000000000000000000000000=";
      wgIp = "10.9.0.2";
    };
    laptop = {
      sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILap";
      wgKey = "laptop0wgPublicKey0000000000000000000000000=";
      wgIp = "10.9.0.3";
    };
  };
  yen.aspects.machine = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        networking.hostName = host.name;
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/sda1";
          fsType = "ext4";
        };
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "25.05";
      };
  };
}
