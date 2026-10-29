{ yen, ... }:
{
  yen.host.box = { };
  yen.guest.web.on = yen.host.box;
  yen.guest.db.on = yen.host.box;

  yen.aspects.box = {
    at = yen.host.box;
    nixos = {
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
