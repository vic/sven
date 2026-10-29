# Den: provides.to-users.includes = with den.aspects; [ desktop openssh … ]. yen: the host joins each feature's `at`.
{ yen, ... }:
let
  host = yen.host.x280;
in
{
  yen.host.x280.shares = [ "//nas/media" ];
  yen.aspects.desktop.at = [ host ];
  yen.aspects.openssh.at = [ host ];
  yen.aspects.x280 = {
    at = host;
    nixos = {
      boot.loader.systemd-boot.enable = true;
      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
    };
  };
  # den.aspects.pol.provides.x280: pol's content, only on this host
  yen.aspects.pol-on-x280 = {
    at = yen.lib.all [
      yen.user.pol
      (yen.lib.within host)
    ];
    nixos.users.users.pol.extraGroups = [ "dialout" ];
  };
}
