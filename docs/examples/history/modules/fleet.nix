# fleet > environment > host. The fleet says which day it is: pure evaluation has no clock.
{ yen, lib, ... }:
let
  inherit (yen.lib) same maybe;
in
{
  yen.kinds.fleet = {
    fields.today = lib.types.str;
    spawns.environment = _: yen.environment;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.dns.out =
      { dns, ... }:
      {
        inherit dns;
      };
  };
  yen.kinds.environment = {
    spawns.host =
      s:
      lib.filterAttrs (_: h: same h.environment s && yen.lib.validAt yen.fleet.main.today h) yen.host;
    sinks.backends.dns =
      { environment, backends, ... }:
      {
        ${environment.name} = backends;
      };
  };
  yen.kinds.host.fields = {
    environment = yen.kinds.environment;
    validFrom = maybe lib.types.str; # null: open, valid since always
    validTo = maybe lib.types.str; # null: open, valid until always
  };

  yen.fleet.main.today = "2026-11-15";
  yen.environment.prod = { };
  yen.host.web-old = {
    environment = yen.environment.prod;
    validTo = "2026-10-31";
  }; # retired
  yen.host.web = {
    environment = yen.environment.prod;
    validFrom = "2026-10-01";
  };
  yen.host.web-next = {
    environment = yen.environment.prod;
    validFrom = "2026-12-01";
  }; # not yet
  yen.flake = { out, ... }: out;
}
