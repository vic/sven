# Kinds are your nouns. `spawns` builds the tree from data. Sinks collect what aspects give.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) same is maybe;
in
{
  yen.kinds.fleet.spawns.env = _: yen.env;
  yen.kinds.fleet.sinks.out.reduce = yen.lib.reduce.merge;
  yen.kinds.env.fields.domain = lib.types.str;
  yen.kinds.env.spawns.host = s: lib.filterAttrs (_: h: same h.env s) yen.host;
  yen.kinds.host.fields = {
    env = yen.kinds.env;
    db = maybe yen.kinds.host;
  };
  yen.kinds.host.spawns.user = s: lib.filterAttrs (_: u: lib.any (same s) u.on) yen.user;
  yen.kinds.host.sinks.os.nixos =
    { os, ... }:
    {
      imports = os;
    }; # os feeds nixos
  yen.kinds.host.sinks.nixos.out =
    { host, nixos, ... }:
    {
      nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
    };
  yen.kinds.user.fields.on = is lib.isList;
  yen.flake = { out, ... }: out;
}
