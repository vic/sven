# nixpkgs.config does not merge: allowUnfreePredicate is a function. `from` collects package names; one module allows them.
#   yen.kinds.host.sinks.unfree.nixos = nixos.unfree { from = yen.kinds.host.sinks.unfree; };
{ from }:
{ sinks, ... }:
{ lib, ... }:
{
  nixpkgs.config.allowUnfreePredicate =
    p: lib.elem (lib.getName p) (lib.flatten sinks.${from.__sink});
}
