# Kits and assemblies: a kit is data; an assembly places machines in its roles with `at` predicates.
{ yen, lib, ... }:
let
  kits = yen.lib.batteries.kits;
  inherit (yen.lib) opt holds same;
  attrs = yen.lib.is lib.isAttrs;
  assemblies = lib.attrValues yen.assembly; # spawns read data
  # tree requests: every assembly and machine, with their data
  allAssemblies.instances = yen.kinds.assembly;
  allMachines.instances = yen.kinds.machine;
in
{
  yen.kinds.fleet = {
    spawns.machine = _: yen.machine;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.machine = {
    fields.storage = opt lib.types.bool false;
    # one member scope per (assembly, role) the machine takes
    spawns.member = kits.members { inherit assemblies holds; };
    sinks.config = {
      reduce = yen.lib.reduce.merge;
      out =
        { scope, sinks, ... }:
        {
          config.${scope.name} = sinks.config;
        };
    };
  };
  yen.kinds.member = { };
  yen.kinds.kit.fields = {
    roles = opt attrs { };
    constraints = opt attrs { };
    exports = opt (yen.lib.is lib.isList) [ ];
  };
  yen.kinds.assembly.fields = {
    kit = yen.kinds.kit;
    roles = opt attrs { };
  };
  yen.kinds.fleet.sinks.exports = {
    reduce = kits.exports { isMember = holds yen.kinds.member; };
    out =
      { sinks, ... }:
      {
        exports = sinks.exports;
      };
  };
  yen.fleet.main = { };
  yen.machine = {
    nas.storage = true;
    web = { };
  };
  yen.flake = { out, ... }: out;

  # what a kit is: its roles, a typed interface per role, limits, the exports it may give
  yen.kit.borg = {
    roles.server = { };
    roles.client.interface.dir = {
      type = lib.types.str;
      default = "/var/backup";
    };
    constraints.roles.server.max = 1;
    exports = [ "endpoint" ];
  };
  yen.assembly.daily = {
    kit = yen.kit.borg;
    roles.server.at = m: m.storage;
    roles.client = {
      at = yen.kinds.machine;
      settings = m: lib.optionalAttrs (same m yen.machine.web) { dir = "/srv/backup"; };
    };
  };

  yen.aspects = {
    contract = {
      at = yen.kinds.fleet;
      cycle =
        { tree, ... }:
        {
          tree = [
            allAssemblies
            allMachines
          ];
          errors = [
            (kits.contract {
              assemblies = lib.head (tree.select allAssemblies);
              machines = lib.head (tree.select allMachines);
              inherit holds;
            })
          ];
        };
    };
    settings-typed = {
      at = yen.kinds.member;
      errors = kits.settings-typed;
    };
    # once per member. The server exports its endpoint; clients read it back.
    borg-server = {
      at = yen.lib.all [
        yen.kinds.member
        (s: same s.kit yen.kit.borg && s.role == "server")
      ];
      exports =
        { scope, ... }:
        {
          endpoint = "${scope.parent.name}:22";
        };
    };
    borg-client = {
      at = yen.lib.all [
        yen.kinds.member
        (s: same s.kit yen.kit.borg && s.role == "client")
      ];
      config =
        { scope, exports, ... }:
        {
          backup.${scope.assembly.name} = {
            inherit (scope.settings) dir;
            to = map (x: x.value.endpoint) (
              lib.filter (x: same x.assembly scope.assembly && x.role == "server") exports
            );
          };
        };
    };
    # one assembly gets more: an aspect at its members
    daily-verbose = {
      at = yen.lib.all [
        yen.kinds.member
        (s: same s.assembly yen.assembly.daily && s.role == "client")
      ];
      config.verbose = true;
    };
  };
}
