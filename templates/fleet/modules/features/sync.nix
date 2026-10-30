# `parent`: alice's syncthing devices are her other parents. `holds` inside content: the tray on desktops.
{ yen, lib, ... }:
{
  yen.aspects.sync = {
    at = yen.kinds.user;
    persist = { user, ... }: "/home/${user.name}/.local/state/syncthing";
    cycle =
      { tree, scope, ... }:
      let
        mine.scopesOf = scope; # a tree request: every scope of this user
      in
      {
        tree = [ mine ];
        homeManager = [
          {
            services.syncthing.enable = true;
            services.syncthing.settings.devices =
              lib.genAttrs
                (map (s: s.parent.name) (lib.filter (s: s.path != scope.path) (lib.head (tree.select mine))))
                (n: {
                  id = builtins.hashString "sha256" n;
                });
            services.syncthing.tray.enable = yen.lib.holds yen.aspects.desktop scope.parent;
          }
        ];
      };
  };
}
