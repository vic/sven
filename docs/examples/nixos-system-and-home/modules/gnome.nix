# One feature, two levels. The desktop is a system concern; its settings are a home concern of each user on it.
{ yen, ... }:
let
  inherit (yen.lib) all within;
in
{
  yen.aspects.gnome = {
    at = yen.host.desk;
    nixos.services.xserver.desktopManager.gnome.enable = true;
  };
  # no home-manager.sharedModules: the users of a host that has gnome get this
  yen.aspects.gnome-home = {
    at = all [
      yen.kinds.user
      (within yen.aspects.gnome)
    ];
    homeManager.dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
}
