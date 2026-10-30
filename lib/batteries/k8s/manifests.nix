#: lib.batteries.k8s.manifests :: { from; lib; output ? ; } -> out value -- Kubernetes manifests from the modules of sink from
# Kubernetes manifests from sink `from`: modules over a freeform attrset, evaluated with lib.evalModules. The value is
# the merged manifests; `name` reads the scope (default: its name).
#   out = k8s.manifests { from = yen.kinds.cluster.sinks.k8s; inherit lib; };  ->  k8sManifests.<cluster> = { … };
{
  from,
  lib,
  output ? "k8sManifests",
}:
{ scope, sinks, ... }@args:
{
  ${output}.${scope.name} = import ../eval-modules.nix {
    inherit from lib;
    modules = [ { freeformType = lib.types.attrsOf lib.types.anything; } ];
  } args;
}
