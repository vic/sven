{ yen, ... }:
{
  yen.kinds.top = {
    spawns.host = _: yen.host;
  };
  yen.kinds.host.sinks.nixos = { };
  yen.top.t = { };
  yen.host.h = { };
  yen.aspects.web = {
    at = yen.kinds.host;
    nixos.services.nginx.enable = true;
  };
  yen.labels = {
    "modules/" = {
      trust = 3;
    };
    "agent/" = {
      trust = 1;
    };
  };
}
