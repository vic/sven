# nixosConfigurations.<scope name> from the modules collected in `from`
#   yen.kinds.host.sinks.nixos.out = nixos.system { from = yen.kinds.host.sinks.nixos; inherit nixpkgs; };
{ from, nixpkgs }:
{ scope, sinks, ... }:
{
  nixosConfigurations.${scope.name} = nixpkgs.lib.nixosSystem { modules = sinks.${from.__sink}; };
}
