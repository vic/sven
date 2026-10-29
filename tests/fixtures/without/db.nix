{ yen, ... }:
{
  yen.host.db = { };
  yen.aspects.postgres = {
    at = yen.host.db;
    nixos.services.postgresql.enable = true;
  };
}
