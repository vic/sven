# distributed builds on the other machines, from sink `from` (reduce entries): each element a `nix.buildMachines`
# entry (`{ hostName; system; maxJobs ? ; sshUser ? ; sshKey ? ; supportedFeatures ? ; … }`). A machine never builds
# on itself; `keep scope builder` picks (default: same system as `systemOf scope`, when given).
#   nixos = nixos.remote-builders { from = yen.kinds.fleet.sinks.builders; systemOf = h: h.system; };
{
  from,
  systemOf ? null,
  keep ? scope: m: systemOf == null || m.system == systemOf scope,
}:
{ scope, sinks, ... }@args:
let
  machines = builtins.filter (keep scope) (
    (import ../mesh.nix) {
      inherit from;
      build = ms: ms;
    } args
  );
in
if machines == [ ] then
  { }
else
  {
    nix.distributedBuilds = true;
    nix.buildMachines = machines;
  }
