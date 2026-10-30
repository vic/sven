# alice: an account on the server, and a standalone home that lives under the server.
{ yen, ... }:
let
  alice = yen.user.alice;
  hers = [
    alice
    (s: yen.lib.holds yen.kinds.home s && yen.lib.same s.user alice)
  ];
in
{
  yen.user.alice.hosts = [ yen.host.server ];
  yen.home."alice@server" = {
    user = alice;
    on = yen.host.server;
    system = "x86_64-linux";
  };

  yen.aspects.alice-account = {
    at = alice;
    nixos.users.users.alice.isNormalUser = true;
  };
  yen.aspects.editors = {
    at = hers; # one module, in NixOS and standalone
    homeManager =
      { osConfig, pkgs, ... }: # osConfig: the host's sink; pkgs: home-manager's own
      {
        home.sessionVariables.EDITOR_HOST = osConfig.networking.hostName;
        home.packages = [ pkgs.nano ];
        home.stateVersion = "25.05";
      };
  };
  yen.aspects.standalone = {
    at = yen.kinds.home;
    homeManager =
      { home, ... }:
      {
        home.username = home.user.name;
        home.homeDirectory = "/home/${home.user.name}";
      };
  };
}
