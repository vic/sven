{ yen, lib, ... }:
{
  yen.aspects.nginx = {
    at = yen.host.web;
    services = "nginx";
  };
  yen.aspects.postgres = {
    at = yen.host.db;
    services = "postgres";
  };
  # the `out` arg: an element reads the flake outputs, lazily. No `inputs.self`.
  yen.aspects.inventory = {
    at = yen.kinds.fleet;
    out =
      { out, ... }:
      {
        inventory = lib.concatLists (lib.attrValues out.services);
      };
  };
}
