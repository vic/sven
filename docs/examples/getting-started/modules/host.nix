# A host has a system. Its `nixos` sink collects NixOS modules and builds the host.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.host = {
    fields.system = lib.types.str;
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem {
          inherit (host) system;
          modules = nixos;
        };
      };
  };

  yen.host.laptop.system = "x86_64-linux";
}
