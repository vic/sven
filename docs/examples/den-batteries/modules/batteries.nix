# Den batteries as yen aspects. A battery's `includes` site becomes the aspect's `at`; its argument becomes a field.
{ yen, lib, ... }:
{
  # den.batteries.hostname
  yen.aspects.hostname = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        networking.hostName = host.name;
      };
  };

  # den.batteries.user-shell: the shell is the user's field
  yen.aspects.user-shell = {
    at = yen.kinds.user;
    nixos =
      { user, pkgs, ... }:
      {
        programs.${user.shell}.enable = lib.mkIf (user.shell != "bash") true;
        users.users.${user.name}.shell = pkgs.${user.shell};
      };
  };

  # den.batteries.tty-autologin: on the hosts that name a user
  yen.aspects.tty-autologin = {
    at = s: s.autologin or null != null;
    nixos =
      { host, ... }:
      {
        services.getty.autologinUser = host.autologin.name;
      };
  };

  # den.batteries.define-user, short
  yen.aspects.define-user = {
    at = yen.kinds.user;
    nixos =
      { user, ... }:
      {
        users.users.${user.name}.isNormalUser = true;
      };
  };

  # Den's `user` class (os-user): a user sink that writes users.users.<name>.
  # yen calls it `account`, because `user` is the arg that holds the user itself.
  # A sink with no elements gives nothing, so keep defaults out of it: they go in define-user.
  yen.kinds.user.sinks.account.nixos =
    { user, account, ... }:
    {
      users.users.${user.name} = lib.mkMerge account;
    };
  yen.aspects.ana-tools = {
    at = yen.user.ana;
    account = {
      description = "Ana";
      extraGroups = [ "wheel" ];
    };
  };
}
