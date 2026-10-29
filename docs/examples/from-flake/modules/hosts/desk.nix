{ yen, ... }:
{
  yen.host.desk = { };
  yen.aspects.desk-hardware = {
    at = yen.host.desk;
    nixos = {
      fileSystems."/" = {
        device = "/dev/nvme0n1p2";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
    };
  };
}
