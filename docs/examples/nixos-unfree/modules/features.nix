# Each feature names the unfree packages it needs, next to the packages. No file knows the whole list.
{ yen, ... }:
{
  yen.aspects.gaming = {
    at = yen.host.desk;
    unfree = [
      "steam"
      "steam-unwrapped"
    ];
    nixos.programs.steam.enable = true;
  };
  # from a user: a user has no `unfree` sink, so the names go up to each of its hosts
  yen.aspects.ana-editor = {
    at = yen.user.ana;
    unfree = [ "vscode" ];
    nixos =
      { pkgs, ... }:
      {
        users.users.ana = {
          isNormalUser = true;
          packages = [ pkgs.vscode ];
        };
      };
  };
}
