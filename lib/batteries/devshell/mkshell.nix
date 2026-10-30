#: lib.batteries.devshell.mkshell :: { from; pkgsOf; } -> out value -- a nixpkgs mkShell at devShells.<scope name>.default
# a nixpkgs mkShell for this scope, from sink `from`: elements `{ packages ? [ ]; shellHook ? ""; }`. The value of
# the sink's `out` key; the shell is `devShells.<scope name>.default`, so give it to a scope named after a system.
#   yen.kinds.system.sinks.devshell.out = devshell.mkshell { from = yen.kinds.system.sinks.devshell;
#     pkgsOf = s: inputs.nixpkgs.legacyPackages.${s.name}; };
{ from, pkgsOf }:
{ scope, sinks, ... }:
let
  es = sinks.${from.__sink};
in
{
  devShells.${scope.name}.default = (pkgsOf scope).mkShell {
    packages = builtins.concatMap (d: d.packages or [ ]) es;
    shellHook = builtins.concatStringsSep "" (map (d: d.shellHook or "") es);
  };
}
