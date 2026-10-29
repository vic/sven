{ yen, ... }:
{
  yen.host.server = { };
  yen.mac.studio = { };

  yen.aspects.server = {
    at = yen.host.server;
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
  yen.aspects.studio = {
    at = yen.mac.studio;
    darwin = {
      nixpkgs.hostPlatform = "aarch64-darwin";
      system.stateVersion = 6;
    };
  };
}
