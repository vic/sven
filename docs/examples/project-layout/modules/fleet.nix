# The root of the tree. Nothing spawns it. Its `out` sink is the flake.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host; # every host lives under the fleet
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
