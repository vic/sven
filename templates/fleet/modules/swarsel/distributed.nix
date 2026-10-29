# swarsel (after oddlama): distributed config. One machine writes NixOS config into another (old `nodes.<name>`),
# and every machine adds fragments to fleet-wide `globals` that any scope reads.
{ yen, lib, ... }:
{
  yen.kinds.fleet.sinks.nodes.reduce = yen.lib.reduce.entries;
  yen.kinds.fleet.sinks.globals.reduce = yen.lib.reduce.merge;
  yen.aspects.lb-writes-backends = {
    at = yen.host.lb;
    nodes =
      { host, ... }:
      lib.genAttrs [ "web-1" "web-2" ] (_: {
        networking.extraHosts = "${host.addr} lb.internal";
      });
  };
  yen.aspects.nodes = {
    at = yen.kinds.host;
    nixos =
      { host, nodes, ... }:
      {
        imports = lib.concatMap (e: lib.optional (e.value ? ${host.name}) e.value.${host.name}) nodes;
      };
  };
  yen.aspects.globals-addr = {
    at = yen.lib.all [
      yen.helpers.machines
      (s: !s.minimal)
    ];
    globals =
      { scope, ... }:
      {
        hosts.${scope.name}.addr = scope.addr;
      };
  };
  yen.aspects.globals-hosts = {
    at = yen.helpers.linux;
    nixos =
      { globals, ... }:
      {
        networking.hosts = lib.mapAttrs' (n: h: lib.nameValuePair h.addr [ "${n}.fleet" ]) globals.hosts;
      };
  };
}
