# a guest (github:microvm-nix/microvm.nix) inside its host: its NixOS modules (sink `from`, at the guest) become
# `microvm.vms.<scope name>` of the host. The value of the guest sink's key that gives to the host's NixOS sink.
#   yen.kinds.guest.sinks.nixos.nixos = microvm.guest { from = yen.kinds.guest.sinks.nixos; pkgs = pkgsOf; };
{ from, pkgs }:
{ scope, sinks, ... }:
{
  microvm.vms.${scope.name} = {
    pkgs = pkgs scope;
    config.imports = sinks.${from.__sink};
  };
}
