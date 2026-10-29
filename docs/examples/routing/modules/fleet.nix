# fleet > environment > host > user and home. Who receives an element depends on where the sinks are.
{ yen, lib, ... }:
let
  inherit (yen.lib) same opt;
  under =
    field: kind: s:
    lib.filterAttrs (_: x: same x.${field} s) kind;
in
{
  yen.kinds.fleet = {
    spawns.environment = _: yen.environment;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.dns.out =
      { dns, ... }:
      {
        dns.fleet = dns;
      }; # the fallback receiver
  };
  yen.kinds.environment = {
    fields.public = opt lib.types.bool false;
    spawns.host = under "environment" yen.host;
    sinks.dns = {
      at = s: s.public; # a conditional receiver: only public environments
      out =
        { environment, dns, ... }:
        {
          dns.${environment.name} = dns;
        };
    };
  };
  yen.kinds.host = {
    fields.environment = yen.kinds.environment;
    spawns = {
      user = under "on" yen.user;
      home = under "on" yen.home;
    };
    sinks.os.out =
      { host, os, ... }:
      {
        os.${host.name} = os;
      };
  };
  yen.kinds.user.fields.on = yen.kinds.host;
  yen.kinds.home = {
    fields.on = yen.kinds.host;
    sinks.os.out =
      { home, os, ... }:
      {
        os.${home.name} = os;
      }; # a home builds its own config
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
