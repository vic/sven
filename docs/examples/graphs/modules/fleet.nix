{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.fields.dependsOn = yen.lib.opt (yen.lib.is lib.isList) [ ]; # host refs

  yen.fleet.main = { };
  yen.host.db = { };
  yen.host.cache = { };
  yen.host.api = {
    dependsOn = [
      yen.host.db
      yen.host.cache
    ];
  };
  yen.host.web = {
    dependsOn = [ yen.host.api ];
  };
  yen.host.lb = {
    dependsOn = [ yen.host.web ];
  };
  yen.flake = { out, ... }: out;
}
