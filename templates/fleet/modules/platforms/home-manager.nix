# Users and standalone homes. A user's homeManager goes to its machine's os, or up to a phone or home.
{ yen, lib, ... }:
let
  inherit (yen.lib)
    within
    opt
    all
    not
    ;
  inherit (yen.helpers)
    machines
    pkgsOf
    flatten
    listOf
    ;
in
{
  yen.kinds.home = {
    fields = {
      user = yen.kinds.user;
      channel = yen.kinds.channel;
      system = yen.kinds.system;
    };
    spawns.user = s: { ${s.user.name} = s.user; };
    sinks.homeManager.out =
      { home, homeManager, ... }:
      {
        homeConfigurations.${home.name} = home.channel.home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsOf home;
          modules = homeManager;
        };
      };
  };
  yen.kinds.user = {
    fields = {
      groups = listOf yen.kinds.group;
      phone = opt lib.types.bool false;
    };
    sinks = {
      homeManager = {
        at = all [
          (within machines)
          (not (within yen.kinds.home))
        ];
        os =
          { user, homeManager, ... }:
          {
            home-manager.users.${user.name}.imports = homeManager;
          };
      };
      homeDarwin = {
        at = within yen.kinds.mac;
        homeManager =
          { homeDarwin, ... }:
          {
            imports = homeDarwin;
          };
      };
      account = {
        at = within machines;
        os =
          { user, account, ... }:
          { pkgs, ... }@a:
          {
            users.users.${user.name} = flatten a account;
          };
      };
    };
  };
}
