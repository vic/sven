# A small fleet to draw: environments hold hosts; a host may refer to its database host.
{ yen, lib, ... }:
let
  inherit (yen.lib) all not maybe;
in
{
  yen.kinds.fleet = {
    spawns.environment = _: yen.environment;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.environment = {
    spawns.host = s: lib.filterAttrs (_: h: yen.lib.same h.environment s) yen.host;
    # hosts report to their environment
    sinks.inventory.out =
      { scope, sinks, ... }:
      {
        inventory.${scope.name} = sinks.inventory;
      };
  };
  yen.kinds.host = {
    fields = {
      environment = yen.kinds.environment;
      db = maybe yen.kinds.host;
    };
    sinks.nixos = { };
  };
  yen.fleet.main = { };
  yen.environment = {
    prod = { };
    dev = { };
  };
  yen.host = {
    web.environment = yen.environment.prod;
    pg.environment = yen.environment.prod;
    lab = {
      environment = yen.environment.dev;
      db = yen.host.pg;
    };
  };
  yen.aspects = {
    server = {
      at = yen.kinds.host;
      inventory = { host, ... }: host.name;
    };
    legacy.at = yen.host.lab;
    monitored = {
      at = all [
        yen.aspects.server
        (not yen.aspects.legacy)
      ];
      nixos.services.prometheus.exporters.node.enable = true;
    };
    alerts.at = yen.aspects.monitored; # names monitored: monitored is a gate, and the diagram shows what it reads
  };
  yen.flake = { out, ... }: out;
}
