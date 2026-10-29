{ sven, ... }:
{
  sven.host.server = { };
  sven.aspects.server = {
    at = sven.host.server;
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
}
