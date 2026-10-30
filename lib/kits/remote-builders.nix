#: lib.kits.remote-builders :: module -- builders and clients: a client builds on the builders of its own assembly
# A builder exports host, systems and speed factor, and gives the `builders` sink one `nix.buildMachines` entry
# (with its assembly and machine, dropped before the client writes it). The client uses the battery
# `nixos.remote-builders` on the entries of its assembly, never on itself. Needs a machine field `addr`.
#   imports = [ inputs.yen.lib.kits.remote-builders ];
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  member =
    role:
    all [
      yen.kinds.member
      (s: same (s.kit or null) yen.kit.remote-builders && s.role == role)
    ];
  battery = yen.lib.batteries.nixos.remote-builders {
    from = yen.kinds.fleet.sinks.builders;
    keep = scope: m: same m.assembly scope.assembly && !same m.machine scope.parent;
  };
in
{
  yen.kinds.fleet.sinks.builders.reduce = yen.lib.reduce.entries;
  yen.kit.remote-builders = {
    roles = {
      builder.interface = {
        systems = {
          type = lib.types.listOf lib.types.str;
          default = [ "x86_64-linux" ];
        };
        speedFactor = {
          type = lib.types.int;
          default = 1;
        };
      };
      client = { };
    };
    constraints.roles.builder.min = 1;
    exports = [
      "host"
      "systems"
      "speedFactor"
    ];
  };
  yen.aspects.builder = {
    at = member "builder";
    exports =
      { scope, member, ... }:
      {
        host = scope.parent.addr;
        inherit (member.settings) systems speedFactor;
      };
    builders =
      { scope, member, ... }:
      {
        hostName = scope.parent.addr;
        inherit (member.settings) speedFactor systems;
        inherit (member) assembly;
        machine = scope.parent;
      };
  };
  yen.aspects.builder-client = {
    at = member "client";
    nixos =
      { scope, sinks, ... }:
      let
        r = battery { inherit scope sinks; };
      in
      if r == { } then
        { }
      else
        r
        // {
          nix.buildMachines = map (
            m:
            removeAttrs m [
              "assembly"
              "machine"
            ]
          ) r.nix.buildMachines;
        };
  };
}
