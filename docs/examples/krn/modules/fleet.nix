{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.fields.apps = yen.lib.is (v: lib.isList v && lib.all lib.isString v);

  yen.fleet.main = { };
  yen.host.lb.apps = [
    "grafana"
    "loki"
    "prometheus"
  ];
  yen.flake = { out, ... }: out;
}
