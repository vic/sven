{ yen, ... }:
{
  yen.host.pi.system = "aarch64-linux";
  yen.aspects.pi = {
    at = yen.host.pi;
    nixos.fileSystems."/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };
}
