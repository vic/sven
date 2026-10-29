# Aspects at guests. None of this reaches the host's own system: an element goes to its nearest `nixos` sink.
{ yen, ... }:
{
  yen.aspects.guest-base = {
    at = yen.kinds.guest;
    nixos =
      { guest, ... }:
      {
        networking.hostName = guest.name;
        system.stateVersion = "25.05";
      };
  };
  yen.aspects.nginx = {
    at = yen.guest.web;
    nixos.services.nginx.enable = true;
  };
  yen.aspects.postgres = {
    at = yen.guest.db;
    nixos.services.postgresql.enable = true;
  };
}
