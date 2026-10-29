# The root kind. Its `report` sink collects one attrset per host and gives it to the flake.
{ yen, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.report = {
      reduce = yen.lib.reduce.merge;
      out =
        { report, ... }:
        {
          inherit report;
        };
    };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
