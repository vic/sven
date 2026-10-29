{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.fleet.main = { };
  yen.host.web = { };
  yen.flake = { out, ... }: out;
}
