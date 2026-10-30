# darwinConfigurations.<scope name>: `darwinSystem` and `system` read the scope (its channel, its system).
#   out = darwin.system { from = yen.kinds.mac.sinks.darwin; darwinSystem = m: m.channel.darwin.lib.darwinSystem;
#     system = m: m.system.name; };
{
  from,
  darwinSystem,
  system,
}:
import ../configurations.nix {
  inherit from;
  output = "darwinConfigurations";
  build =
    s: modules:
    darwinSystem s {
      system = system s;
      inherit modules;
    };
}
