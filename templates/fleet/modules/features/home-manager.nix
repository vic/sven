# One aspect, two platform keys: each key lands where its sink is.
{ yen, ... }:
let
  inherit (yen.lib) all within;
in
{
  yen.aspects.hm-module = {
    at = yen.helpers.machines;
    nixos =
      { scope, ... }:
      {
        imports = [ scope.channel.home-manager.nixosModules.home-manager ];
      };
    darwin =
      { scope, ... }:
      {
        imports = [ scope.channel.home-manager.darwinModules.home-manager ];
      };
  };
  yen.aspects.hm-state = {
    at = yen.kinds.user;
    homeManager.home.stateVersion = "25.05";
  };
  yen.aspects.hm-standalone = {
    at = all [
      yen.kinds.user
      (within yen.kinds.home)
    ];
    homeManager =
      { user, ... }:
      {
        home.username = user.name;
        home.homeDirectory = "/home/${user.name}";
      };
  };
  yen.aspects.ssh-agent = {
    at = all [
      yen.kinds.user
      (within yen.helpers.linux)
    ];
    homeManager.services.ssh-agent.enable = true;
  }; # the home-manager service is Linux only
  yen.aspects.htop = {
    at = all [
      yen.user.alice
      (within yen.host.web-1)
    ];
    homeManager.programs.htop.enable = true;
  }; # host-qualified
  yen.aspects.tiling = {
    at = yen.kinds.user;
    homeDarwin.programs.aerospace.enable = true;
  }; # only mac users have homeDarwin
  yen.aspects.dev = {
    at = [
      yen.helpers.machines
      yen.kinds.user
    ];
    os =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.git ];
      };
    homeManager.programs.git.enable = true;
  };
}
