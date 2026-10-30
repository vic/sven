# kits and assemblies in yen. A kit is data: roles, a typed interface per role, constraints, the export keys it may
# give, and the assemblies it adds. An assembly is one use of a kit: its `kit` is a ref, each role's machines an `at`
# predicate. Each machine spawns one `member` scope per (assembly, role) it takes, so an aspect at a member scope runs
# once per assembly and role, and an aspect at the machine that `has` a member runs once per machine.
# Exports are a fleet sink: the engine sets `from` (the member scope), so a kit cannot write another's scope.
# The rules are yen.lib.batteries.kits; this file is the fleet's data and its words.
{ yen, lib, ... }:
let
  inherit (yen.lib) opt holds;
  kits = yen.lib.batteries.kits;
  attrs = yen.lib.is lib.isAttrs;
  # a kit that needs another kit adds assemblies of it, per assembly of its own
  added =
    a:
    lib.mapAttrsToList (
      name: v:
      v
      // {
        kind = "assembly";
        inherit name;
      }
    ) (a.kit.adds a);
  own = lib.attrValues yen.assembly;
  assemblies = own ++ lib.concatMap added own;
  machines = lib.attrValues yen.host ++ lib.attrValues yen.mac;
  membersOf = kits.members { inherit assemblies holds; };
in
{
  yen.kinds.kit.fields = {
    roles = opt attrs { };
    constraints = opt attrs { };
    exports = opt (yen.helpers.listOf lib.types.str) [ ];
    adds = opt (yen.lib.is lib.isFunction) (_: { });
  };
  yen.kinds.assembly.fields = {
    kit = yen.kinds.kit;
    roles = opt attrs { };
  };
  yen.helpers.assemblies = assemblies;
  yen.kinds.member = { }; # spawned under machines; its elements go up to the machine
  yen.kinds.host.spawns.member = membersOf;
  yen.kinds.mac.spawns.member = membersOf;

  # one fleet sink for exports; a reader keeps the entries of one assembly and role (`yen.lib.same`).
  # An element from the fleet scope is the owner's override of one entry.
  yen.kinds.fleet.sinks.exports.reduce = kits.exports { isMember = holds yen.kinds.member; };

  # the contract: a kit ref, known roles, `at` predicates, machine and assembly counts; typed settings per member
  yen.aspects.kits-contract = {
    at = yen.kinds.fleet;
    errors = kits.contract { inherit assemblies machines holds; };
  };
  yen.aspects.kits-settings-typed = {
    at = yen.kinds.member;
    errors = kits.settings-typed;
  };
}
