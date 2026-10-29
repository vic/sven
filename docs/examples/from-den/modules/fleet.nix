# What Den gives you built in, declared: hosts build NixOS, users live on hosts, a user's home goes into its host.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    fields.system = lib.types.str;
    spawns.user = s: lib.filterAttrs (_: u: lib.any (yen.lib.same s) u.hosts) yen.user;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem {
          inherit (host) system;
          modules = nixos;
        };
      };
  };
  yen.kinds.user = {
    fields.hosts = yen.lib.is lib.isList;
    sinks.homeManager.nixos =
      { user, homeManager, ... }:
      {
        home-manager.users.${user.name}.imports = homeManager;
      };
  };
  yen.aspects.home-manager = {
    at = yen.lib.has yen.kinds.user;
    nixos.imports = [ inputs.home-manager.nixosModules.home-manager ];
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
