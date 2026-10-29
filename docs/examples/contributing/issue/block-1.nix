# The fleet: a root kind, and a host kind with an `admin` sink that takes one element.
{ yen, ... }:
{
  yen.kinds.fleet.spawns.host = _: yen.host;
  yen.kinds.host.sinks.admin.reduce = yen.lib.reduce.one;
  yen.fleet.main = { };
  yen.host.web = { };
}
