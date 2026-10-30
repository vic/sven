# A clan-like inventory: services and instances are data; machines take roles by name or tag.
{ yen, lib, ... }:
let
  clan = yen.lib.batteries.clan;
  str = lib.types.str;
  machines = lib.attrValues yen.machine;
  labelsOf = m: [ "all" ] ++ m.tags;
  # what a service is: its roles, a typed interface per role, limits, the exports it may give
  services = {
    borg = {
      roles.server = { };
      roles.client.interface.dir = {
        type = str;
        default = "/var/backup";
      };
      constraints.roles.server.max = 1;
      exports = [ "endpoint" ];
    };
  };
  instances.daily = {
    module = "borg";
    roles.server.tags = [ "storage" ];
    roles.client = {
      tags = [
        "all"
        "laptops"
      ]; # no machine has `laptops`: a warning
      extraModules = [ { services.borg.verbose = true; } ];
      machines.web.settings.dir = "/srv/backup";
    };
  };
in
{
  yen.kinds.fleet = {
    spawns.machine = _: yen.machine;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.machine = {
    fields.tags = yen.lib.opt (yen.lib.is lib.isList) [ ];
    # one member scope per (instance, role) the machine takes part in
    spawns.member = clan.members { inherit instances services labelsOf; };
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
  yen.kinds.fleet.sinks.exports = {
    reduce = clan.exports {
      inherit services;
      isMember = yen.lib.holds yen.kinds.member;
    };
    out =
      { sinks, ... }:
      {
        exports = sinks.exports;
      };
  };
  yen.fleet.main = { };
  yen.machine = {
    nas.tags = [ "storage" ];
    web = { };
  };
  yen.flake = { out, ... }: out;

  yen.kinds.fleet.sinks.warnings.out =
    { sinks, ... }:
    {
      warnings = sinks.warnings;
    };
  yen.aspects = {
    unknown-tags = {
      at = yen.kinds.fleet;
      warnings = clan.unknown-tags { inherit instances machines labelsOf; };
    };
    extra-modules = {
      at = yen.lib.all [
        yen.kinds.member
        (s: s.extraModules != [ ])
      ];
      config = clan.extra-modules;
    };
    contract = {
      at = yen.kinds.fleet;
      errors = clan.contract {
        inherit
          instances
          services
          machines
          labelsOf
          ;
      };
    };
    settings-typed = {
      at = yen.kinds.member;
      errors = clan.settings-typed { inherit services; };
    };
    # perInstance: once per member. The server exports its endpoint; clients read it back.
    borg-server = {
      at = yen.lib.all [
        yen.kinds.member
        (s: s.service == "borg" && s.role == "server")
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
        (s: s.service == "borg" && s.role == "client")
      ];
      config =
        { scope, exports, ... }:
        {
          backup.${scope.instance} = {
            inherit (scope.settings) dir;
            to = map (x: x.value.endpoint) (lib.filter (x: x.role == "server") exports);
          };
        };
    };
  };
}
