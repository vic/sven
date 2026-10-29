# base: every machine. Its `records` key lives in dns.nix: one aspect, two files.
{ yen, lib, ... }:
{
  yen.aspects.base = {
    at = yen.helpers.machines;
    os =
      { scope, overlays, ... }:
      {
        networking.hostName = scope.name;
        nixpkgs.overlays = overlays;
      };
  };
  yen.aspects.hardware = {
    # enough for a real toplevel
    at = yen.kinds.host;
    nixos = {
      fileSystems."/" = {
        device = "/dev/disk/by-label/root";
        fsType = "ext4";
      };
      fileSystems."/persist" = {
        device = "/dev/disk/by-label/persist";
        fsType = "ext4";
        neededForBoot = true;
      };
      boot.loader.grub.device = "nodev";
    };
  };
  yen.aspects.state-version = {
    at = yen.helpers.linux;
    nixos.system.stateVersion = "25.05";
  };
  yen.aspects.user-account = {
    at = yen.lib.all [
      yen.kinds.user
      (yen.lib.within yen.helpers.linux)
    ];
    account.isNormalUser = true;
  }; # NixOS only
  yen.aspects.user-account-mac = {
    at = yen.lib.all [
      yen.kinds.user
      (yen.lib.within yen.kinds.mac)
    ];
    account =
      { user, ... }:
      {
        home = "/Users/${user.name}";
      };
  };
}
