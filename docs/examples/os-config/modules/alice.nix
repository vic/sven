# alice: an account on the server, and a standalone home that lives under the server.
{ sven, ... }:
let
  alice = sven.user.alice;
  hers = [
    alice
    (s: s.kind == "home" && sven.lib.same s.user alice)
  ];
in
{
  sven.user.alice.hosts = [ sven.host.server ];
  sven.home."alice@server" = {
    user = alice;
    on = sven.host.server;
    system = "x86_64-linux";
  };

  sven.aspects.alice-account = {
    at = alice;
    nixos.users.users.alice.isNormalUser = true;
  };
  sven.aspects.editors = {
    at = hers; # one module, in NixOS and standalone
    homeManager =
      { osConfig, pkgs, ... }: # osConfig: the host's sink; pkgs: home-manager's own
      {
        home.sessionVariables.EDITOR_HOST = osConfig.networking.hostName;
        home.packages = [ pkgs.nano ];
        home.stateVersion = "25.05";
      };
  };
  sven.aspects.standalone = {
    at = sven.kinds.home;
    homeManager =
      { home, ... }:
      {
        home.username = home.user.name;
        home.homeDirectory = "/home/${home.user.name}";
      };
  };
}
