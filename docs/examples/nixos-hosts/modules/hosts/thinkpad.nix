{ yen, ... }:
{
  yen.host.thinkpad.laptop = true;
  yen.aspects.thinkpad = {
    at = yen.host.thinkpad;
    nixos = {
      boot.loader.systemd-boot.enable = true;
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
    };
  };
}
