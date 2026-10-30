# Your words: hosts build NixOS and hold users. The batteries fill values; every key here is yours.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  nixos = yen.lib.batteries.nixos;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    spawns.user = s: lib.filterAttrs (_: u: lib.any (yen.lib.same s) u.hosts) yen.user;
    sinks.nixos.out = nixos.system {
      from = yen.kinds.host.sinks.nixos;
      inherit (inputs) nixpkgs;
    };
    # package names from any feature or user; one module per host allows them
    sinks.unfree.nixos = nixos.unfree { from = yen.kinds.host.sinks.unfree; };
    sinks.insecure.nixos = nixos.insecure { from = yen.kinds.host.sinks.insecure; };
  };
  yen.kinds.user.fields = {
    hosts = yen.lib.is lib.isList;
    shell = yen.lib.opt (lib.types.enum [
      "bash"
      "fish"
      "zsh"
    ]) "bash";
  };
  yen.kinds.host.fields.autologin = yen.lib.maybe yen.kinds.user;

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
