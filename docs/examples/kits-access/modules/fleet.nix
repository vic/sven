# The fleet's words: machines, kits and assemblies, and the sinks the access kits write to and read from.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  kits = yen.lib.batteries.kits;
  inherit (yen.lib) opt holds;
  attrs = yen.lib.is lib.isAttrs;
  assemblies = lib.attrValues yen.assembly;
  machines = lib.attrValues yen.machine;
  # what a machine gets, the NixOS values of its modules merged for the page
  merged = ms: lib.foldl' lib.recursiveUpdate { } (lib.filter lib.isAttrs ms);
in
{
  imports = [
    inputs.yen.lib.kits.sshd
    inputs.yen.lib.kits.users
    inputs.yen.lib.kits.emergency-access
  ];
  yen.kinds.fleet = {
    spawns.machine = _: yen.machine;
    sinks.out.reduce = yen.lib.reduce.merge;
    sinks.exports.reduce = kits.exports { isMember = holds yen.kinds.member; };
    sinks.generators.reduce = yen.lib.batteries.vars.generators {
      machineOf = s: if holds yen.kinds.member s then s.parent else s;
    };
  };
  yen.kinds.machine = {
    spawns.member = kits.members { inherit assemblies holds; };
    sinks.nixos.out =
      { scope, nixos, ... }:
      {
        nixos.${scope.name} = merged nixos;
      };
    sinks.os.out =
      { scope, os, ... }:
      {
        os.${scope.name} = merged os;
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
  yen.fleet.main = { };
  yen.machine = {
    web = { };
    db = { };
  };
  yen.flake = { out, ... }: out;

  yen.aspects = {
    contract = {
      at = yen.kinds.fleet;
      errors = kits.contract { inherit assemblies machines holds; };
    };
    settings-typed = {
      at = yen.kinds.member;
      errors = kits.settings-typed;
    };
  };
}
