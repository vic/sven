# alice: an account on the server, and a standalone home for her laptop (any Linux, no NixOS).
{ yen, ... }:
let
  alice = yen.user.alice;
  # her own scopes, and every home that belongs to her
  hers = [
    alice
    (s: s.kind == "home" && yen.lib.same s.user alice)
  ];
in
{
  yen.user.alice.hosts = [ yen.host.server ];
  yen.home."alice@laptop" = {
    user = alice;
    system = "x86_64-linux";
  };

  yen.aspects.alice-account = {
    at = alice;
    nixos.users.users.alice = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
  };
  yen.aspects.alice-home = {
    at = hers; # one home config, in NixOS and standalone
    homeManager = {
      programs.git = {
        enable = true;
        userName = "Alice";
      };
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
