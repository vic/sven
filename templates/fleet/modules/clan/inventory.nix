# clan's inventory in yen: a service instance is data. Each machine spawns one `member` scope per (instance, role)
# it takes part in, so an aspect at a member scope runs once per instance (clan perInstance) and an aspect at the
# machine that `has` a member runs once per machine (clan perMachine). Members read every instance as data.
# Exports are a fleet sink: the engine sets `from` (the member scope), so a service cannot write another's scope.
# The rules are yen.lib.batteries.clan; this file is the fleet's data and its words.
{ yen, lib, ... }:
let
  inherit (yen.lib) opt;
  clan = yen.lib.batteries.clan;
  attrs = yen.lib.is lib.isAttrs;
  # clan's automatic tags: all, and the machine class
  labelsOf =
    m:
    [
      "all"
      (if yen.lib.holds yen.kinds.mac m then "darwin" else "nixos")
    ]
    ++ m.labels;
  service = i: yen.helpers.clan.services.${i.module} or null;
  all = yen.helpers.clan.instances;
  inherit (yen.helpers.clan) services;
  machines = lib.attrValues yen.host ++ lib.attrValues yen.mac;
in
{
  yen.kinds.machine.fields.labels = opt (yen.helpers.listOf lib.types.str) [ ];
  yen.kinds.instance.fields = {
    module = yen.lib.derive lib.types.str (self: self.name);
    roles = opt attrs { };
  };
  yen.helpers.clan = {
    services = { };
    # instances as data, plus the instances services add (clan nested services)
    instances = yen.instance // lib.concatMapAttrs (_: i: (service i).adds or (_: { }) i) yen.instance;
    selectExports = q: lib.filter (e: lib.all (k: e.${k} == q.${k}) (lib.attrNames q));
    membersOf = clan.members {
      instances = all;
      inherit services labelsOf;
    };
  };
  yen.kinds.member = { }; # spawned under machines; its elements go up to the machine
  yen.kinds.host.spawns.member = s: yen.helpers.clan.membersOf s;
  yen.kinds.mac.spawns.member = s: yen.helpers.clan.membersOf s;

  # one fleet sink for exports; a reader filters by service, instance, role and machine (clan selectExports).
  # A member writes only under its own scope. An element from the fleet scope is the owner's override of one entry.
  # A service lists the export keys it may give (clan manifest.exports.out).
  yen.kinds.fleet.sinks.exports.reduce = clan.exports {
    inherit services;
    isMember = yen.lib.holds yen.kinds.member;
  };
  yen.aspects.clan-extra-modules = {
    at = yen.lib.all [
      yen.kinds.member
      (s: s.extraModules != [ ])
    ];
    os = clan.extra-modules;
  };

  # clan's instance contract: known service and roles, at least one role, machine and instance counts, typed settings
  yen.aspects.clan-contract = {
    at = yen.kinds.fleet;
    errors = clan.contract {
      instances = all;
      inherit services machines labelsOf;
    };
  };
  # a tag that names no machine is a warning, not an error (clan resolveTags): a user sink anyone may read
  yen.kinds.fleet.sinks.warnings.reduce = yen.lib.reduce.list;
  yen.aspects.clan-unknown-tags = {
    at = yen.kinds.fleet;
    warnings = clan.unknown-tags {
      instances = all;
      inherit machines labelsOf;
    };
  };
  yen.aspects.clan-settings-typed = {
    at = yen.kinds.member;
    errors = clan.settings-typed { inherit services; };
  };
}
