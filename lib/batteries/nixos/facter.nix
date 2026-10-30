# nixos-facter: the hardware report that `report` reads from the scope. Put the aspect where the report exists:
#   at = all [ yen.kinds.host (h: builtins.pathExists ./hosts/${h.name}/facter.json) ];
#   nixos = nixos.facter { report = h: ./hosts/${h.name}/facter.json; };
# `module`: the facter NixOS module, when your nixpkgs has none (inputs.nixos-facter-modules.nixosModules.facter).
{
  report,
  module ? null,
}:
{ scope, ... }:
{
  hardware.facter.reportPath = report scope;
}
// (if module == null then { } else { imports = [ module ]; })
