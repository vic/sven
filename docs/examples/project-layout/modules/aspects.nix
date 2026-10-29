# Behavior: active at every host, gives one NixOS module to the `nixos` sink.
{ yen, ... }:
{
  yen.aspects.base = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        networking.hostName = host.name;
        boot.loader.grub.device = "nodev";
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        system.stateVersion = "25.05";
      };
  };

  yen.aspects.motd = {
    at = yen.host.laptop;
    nixos.environment.etc.motd.text = "managed by yen";
  };
}
