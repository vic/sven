# A guest lives under its host. Its own `nixos` sink forwards up, into the host's containers.
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
    spawns.guest = s: lib.filterAttrs (_: g: yen.lib.same g.on s) yen.guest;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.guest = {
    fields.on = yen.kinds.host;
    sinks.nixos.nixos =
      { guest, nixos, ... }:
      {
        containers.${guest.name} = {
          autoStart = true;
          config.imports = nixos;
        };
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
