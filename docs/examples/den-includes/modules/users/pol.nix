# Den: den.aspects.pol = { config, ... }: { meta.fullname = …; user.description = config.meta.fullname; }.
# yen: meta is fields of the instance. Any file reads them as `yen.user.pol.fullname`, or as the `user` arg.
{ yen, ... }:
{
  yen.user.pol = {
    hosts = [
      yen.host.x280
      yen.host.rpi4
    ];
    fullname = "Pol";
    authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPol" ];
  };
  # define-user + primary-user, for every user
  yen.aspects.account = {
    at = yen.kinds.user;
    nixos =
      { user, ... }:
      {
        users.users.${user.name} = {
          isNormalUser = true;
          description = user.fullname;
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = user.authorizedKeys;
        };
      };
  };
}
