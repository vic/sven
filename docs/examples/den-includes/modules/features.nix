# Features without `at`: each host file says which ones it has.
{ lib, ... }:
{
  yen.aspects.desktop.nixos.services.xserver.desktopManager.gnome.enable = true;
  yen.aspects.openssh.nixos.services.openssh.enable = true;
  # (den.aspects.mount-cifs "//nas/media"): the parameters are the host's `shares` field
  yen.aspects.shares = {
    at = s: (s.shares or [ ]) != [ ];
    nixos =
      { host, ... }:
      {
        fileSystems = lib.listToAttrs (
          map (
            share:
            lib.nameValuePair "/mnt/${baseNameOf share}" {
              device = share;
              fsType = "cifs";
              options = [ "noauto" ];
            }
          ) host.shares
        );
      };
  };
}
