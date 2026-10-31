# The fleet's words: hosts with an address, members of assemblies, and the sinks the library kits write to.
{ yen, lib, ... }:
let
  kits = yen.lib.batteries.kits;
  inherit (yen.lib) opt holds;
  attrs = yen.lib.is lib.isAttrs;
  # a kit that adds assemblies of another kit (borg adds sshd), per assembly of its own
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
  machineOf = s: if holds yen.kinds.member s then s.parent else s;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks = {
      out.reduce = yen.lib.reduce.merge;
      exports.reduce = kits.exports { isMember = holds yen.kinds.member; };
      generators = {
        reduce = yen.lib.batteries.vars.generators { inherit machineOf; };
        out = yen.lib.batteries.vars.vars-plan {
          from = yen.kinds.fleet.sinks.generators;
          machines = lib.attrNames yen.host;
          recipientsOf = _: [ "age1admin" ];
        };
      };
    };
  };
  yen.kinds.host = {
    fields.addr = lib.types.str;
    spawns.member = kits.members { inherit assemblies holds; };
    # the NixOS keys of a host, as data
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
    roles = opt attrs { };
    constraints = opt attrs { };
    exports = opt (yen.lib.is lib.isList) [ ];
    adds = opt (yen.lib.is lib.isFunction) (_: { });
  };
  yen.kinds.assembly.fields = {
    kit = yen.kinds.kit;
    roles = opt attrs { };
  };
  yen.aspects.contract = {
    at = yen.kinds.fleet;
    errors = kits.contract {
      inherit assemblies holds;
      machines = lib.attrValues yen.host;
    };
  };
  yen.aspects.settings-typed = {
    at = yen.kinds.member;
    errors = kits.settings-typed;
  };
  # a generator that an export carries goes to the machines of its `deploy` predicate
  yen.aspects.generators-from-exports = {
    at = yen.kinds.host;
    generators =
      { scope, exports, ... }:
      let
        gens = lib.concatMap (
          x: lib.filter (g: holds g.deploy scope) (lib.attrValues (x.value.generators or { }))
        ) exports;
      in
      if gens == [ ] then
        null
      else
        {
          name = "from-exports";
          files = lib.foldl' (a: g: a // g.files) { } gens;
        };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
