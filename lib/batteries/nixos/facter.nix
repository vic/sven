#: lib.batteries.nixos.facter :: { report; module ? ; option ? ; } -> key value -- nixos-facter with the report that report reads
# nixos-facter: the hardware report that `report` reads from the scope. Put the aspect where the report exists:
#   at = all [ yen.kinds.host (h: builtins.pathExists ./hosts/${h.name}/facter.json) ];
#   nixos = nixos.facter { report = h: ./hosts/${h.name}/facter.json; };
# `module`: the facter NixOS module, when your nixpkgs has none (inputs.nixos-facter-modules.nixosModules.facter).
# Its option is `facter.reportPath`; NixOS's own is `hardware.facter.reportPath`. `option` overrides the path.
{
  report,
  module ? null,
  option ?
    if module == null then
      [
        "hardware"
        "facter"
        "reportPath"
      ]
    else
      [
        "facter"
        "reportPath"
      ],
}:
{ scope, ... }:
let
  b = builtins;
  at =
    path: v:
    b.foldl' (acc: k: { ${k} = acc; }) v (
      b.genList (i: b.elemAt path (b.length path - 1 - i)) (b.length path)
    );
in
at option (report scope) // (if module == null then { } else { imports = [ module ]; })
