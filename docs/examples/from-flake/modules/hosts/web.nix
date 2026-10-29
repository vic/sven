{ yen, ... }:
{
  yen.host.web = { };
  yen.aspects.web-hardware = {
    at = yen.host.web;
    nixos = {
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
    };
  };
}
