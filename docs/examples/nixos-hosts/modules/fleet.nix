# Hosts are data. One kind builds every NixOS system: no mkHost function, no readDir, no specialArgs.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) opt;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    # what a vars.nix file held: typed, with defaults
    fields = {
      system = opt (lib.types.enum [
        "x86_64-linux"
        "aarch64-linux"
      ]) "x86_64-linux";
      laptop = opt lib.types.bool false;
    };
    sinks.nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
