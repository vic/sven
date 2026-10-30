#: lib.batteries.home-manager.system :: { from; homeManagerConfiguration; pkgs; } -> out value -- homeConfigurations.<scope name>, a standalone home
# homeConfigurations.<scope name>, a standalone home: `homeManagerConfiguration` and `pkgs` read the scope.
#   out = home-manager.system { from = yen.kinds.home.sinks.homeManager; pkgs = h: pkgsOf h;
#     homeManagerConfiguration = h: h.channel.home-manager.lib.homeManagerConfiguration; };
{
  from,
  homeManagerConfiguration,
  pkgs,
}:
import ../configurations.nix {
  inherit from;
  output = "homeConfigurations";
  build =
    s: modules:
    homeManagerConfiguration s {
      pkgs = pkgs s;
      inherit modules;
    };
}
