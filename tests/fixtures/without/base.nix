{ yen, ... }:
{
  yen.kinds.top = {
    spawns.host = _: yen.host;
    sinks.peers = { };
  };
  yen.kinds.host = {
    sinks.nixos = { };
  };
  yen.top.t = { };
  yen.host.web = { };
  yen.aspects.peer = {
    at = yen.kinds.host;
    peers = { host, ... }: host.name;
  };
}
