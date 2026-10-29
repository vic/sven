# What every NixOS host needs to evaluate. Not part of the story.
{ yen, ... }:
{
  yen.aspects.hardware = {
    at = yen.kinds.host;
    os = {
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
