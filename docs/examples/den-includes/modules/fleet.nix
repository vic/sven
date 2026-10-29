# Den's schema, declared. A user's `meta` attrs become typed fields; `facter ./facter.json` becomes a host field.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) opt is;
  strs = lib.types.listOf lib.types.str;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    fields = {
      system = opt lib.types.str "x86_64-linux";
      shares = opt strs [ ]; # parameters of a parametric aspect
    };
    spawns.user = s: lib.filterAttrs (_: u: lib.any (yen.lib.same s) u.hosts) yen.user;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.user.fields = {
    hosts = is lib.isList;
    fullname = lib.types.str;
    authorizedKeys = opt strs [ ];
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
