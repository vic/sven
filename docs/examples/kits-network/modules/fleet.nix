# The words of this fleet: machines with an address, a `nixos` sink, the kits' contract and exports.
{ yen, lib, ... }:
let
  kits = yen.lib.batteries.kits;
  inherit (yen.lib) opt holds;
  assemblies = lib.attrValues yen.assembly;
in
{
  yen.kinds.fleet = {
    spawns.machine = _: yen.machine;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.exports = {
      reduce = kits.exports { isMember = holds yen.kinds.member; };
      out =
        { sinks, ... }:
        {
          exports = sinks.exports;
        };
    };
  };
  yen.kinds.machine = {
    fields.addr = yen.lib.is lib.isString;
    spawns.member = kits.members { inherit assemblies holds; };
    sinks.nixos = {
      reduce = yen.lib.reduce.merge;
      out =
        { scope, sinks, ... }:
        {
          config.${scope.name} = sinks.nixos;
        };
    };
  };
  yen.kinds.member = { };
  yen.kinds.kit.fields = {
    roles = opt (yen.lib.is lib.isAttrs) { };
    constraints = opt (yen.lib.is lib.isAttrs) { };
    exports = opt (yen.lib.is lib.isList) [ ];
  };
  yen.kinds.assembly.fields = {
    kit = yen.kinds.kit;
    roles = opt (yen.lib.is lib.isAttrs) { };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
  yen.aspects.contract = {
    at = yen.kinds.fleet;
    errors = kits.contract {
      inherit assemblies holds;
      machines = lib.attrValues yen.machine;
    };
  };
  yen.aspects.settings-typed = {
    at = yen.kinds.member;
    errors = kits.settings-typed;
  };
}
