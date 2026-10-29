# Two hosts and two users. The fleet carries constants; a user's `admin` field replaces a user factory's argument.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) opt is;
in
{
  yen.kinds.fleet = {
    fields.adminEmail = lib.types.str;
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    fields.gpu = opt (lib.types.enum [
      "none"
      "nvidia"
    ]) "none";
    spawns.user = s: lib.filterAttrs (_: u: lib.any (yen.lib.same s) u.hosts) yen.user;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.user.fields = {
    hosts = is lib.isList;
    admin = opt lib.types.bool false;
  };

  yen.fleet.main.adminEmail = "admin@example.org";
  yen.flake = { out, ... }: out;

  yen.host.desk.gpu = "nvidia";
  yen.host.srv = { };
  yen.user.bob = {
    hosts = [ yen.host.desk ];
    admin = true;
  };
  yen.user.eve.hosts = [
    yen.host.desk
    yen.host.srv
  ];
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
