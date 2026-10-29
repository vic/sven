# `parent`: alice's syncthing devices are her other parents. `holds` inside content: the tray on desktops.
{ yen, lib, ... }:
{
  yen.aspects.sync = {
    at = yen.kinds.user;
    persist = { user, ... }: "/home/${user.name}/.local/state/syncthing";
    homeManager =
      { user, scope, ... }:
      {
        services.syncthing.enable = true;
        services.syncthing.settings.devices =
          lib.genAttrs (map (s: s.parent.name) (lib.filter (s: s.path != scope.path) (yen.lib.scopesOf user)))
            (n: {
              id = builtins.hashString "sha256" n;
            });
        services.syncthing.tray.enable = yen.lib.holds yen.aspects.desktop scope.parent;
      };
  };
}
