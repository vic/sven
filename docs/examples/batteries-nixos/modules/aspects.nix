# Den's hostname, define-user and primary-user, as values of aspects you name.
{ yen, ... }:
let
  nixos = yen.lib.batteries.nixos;
in
{
  yen.aspects.hostname = {
    at = yen.kinds.host;
    nixos = nixos.hostname;
  };
  yen.aspects.accounts = {
    at = yen.kinds.user; # a user has no `nixos` sink: its account goes into each of its hosts
    nixos = nixos.define-user;
  };
  yen.aspects.admin = {
    at = yen.user.ana;
    nixos = nixos.primary-user;
  };
  # Den's user-shell and tty-autologin: the battery reads the field you name
  yen.aspects.shells = {
    at = yen.kinds.user;
    nixos = nixos.user-shell { shell = u: u.shell; };
  };
  yen.aspects.autologin = {
    at = yen.kinds.host;
    nixos = nixos.autologin { user = h: h.autologin; };
  };
}
