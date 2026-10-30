# nixosConfigurations.<scope name> from the modules collected in `from`
#   yen.kinds.host.sinks.nixos.out = nixos.system { from = yen.kinds.host.sinks.nixos; inherit nixpkgs; };
{ from, nixpkgs }:
import ../configurations.nix {
  inherit from;
  output = "nixosConfigurations";
  build = _: modules: nixpkgs.lib.nixosSystem { inherit modules; };
}
