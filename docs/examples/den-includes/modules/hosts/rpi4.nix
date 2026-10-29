{ yen, ... }:
{
  yen.host.rpi4.system = "aarch64-linux";
  yen.aspects.openssh.at = [ yen.host.rpi4 ]; # `at` from two files is a union
  yen.aspects.rpi4 = {
    at = yen.host.rpi4;
    nixos = {
      boot.loader.generic-extlinux-compatible.enable = true;
      fileSystems."/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
      };
    };
  };
}
