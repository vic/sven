#: lib.batteries.droid.system :: { from; nixOnDroidConfiguration; pkgs; } -> out value -- nixOnDroidConfigurations.<scope name>
# nixOnDroidConfigurations.<scope name> (github:nix-community/nix-on-droid): `pkgs` reads the scope.
#   out = droid.system { from = yen.kinds.phone.sinks.droid; inherit (inputs.nix-on-droid.lib) nixOnDroidConfiguration; pkgs = pkgsOf; };
{
  from,
  nixOnDroidConfiguration,
  pkgs,
}:
import ../configurations.nix {
  inherit from;
  output = "nixOnDroidConfigurations";
  build =
    s: modules:
    nixOnDroidConfiguration {
      pkgs = pkgs s;
      inherit modules;
    };
}
