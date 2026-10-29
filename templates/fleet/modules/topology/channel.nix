# Channels: which nixpkgs and home-manager a machine builds with.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.channel.fields = {
    nixpkgs = lib.types.raw;
    home-manager = lib.types.raw;
    darwin = yen.lib.opt lib.types.raw null;
  };
  yen.channel.stable = {
    nixpkgs = inputs.nixpkgs;
    home-manager = inputs.home-manager;
    darwin = inputs.nix-darwin;
  };
  yen.channel.edge = {
    nixpkgs = inputs.nixpkgs-unstable;
    home-manager = inputs.home-manager-unstable;
  };
}
