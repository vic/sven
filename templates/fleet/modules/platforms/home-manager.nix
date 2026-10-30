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
    sinks.homeManager.out = yen.lib.batteries.home-manager.system {
      from = yen.kinds.home.sinks.homeManager;
      homeManagerConfiguration = h: h.channel.home-manager.lib.homeManagerConfiguration;
      pkgs = pkgsOf;
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
        os = yen.lib.batteries.home-manager.into-host { from = yen.kinds.user.sinks.homeManager; };
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
