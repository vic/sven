# The fleet as yen queries, outside the flake: the same module flake.nix gives mkFlake.
# Run: nix eval --impure --file query.nix errors
let
  inputs = (builtins.getFlake "path:${toString ../..}?dir=templates/fleet").inputs; # in the yen tree: `../..` resolves
in
inputs.yen.lib.eval {
  imports = [ (inputs.import-tree ./modules) ];
  inherit inputs;
  inherit (inputs.nixpkgs) lib;
}
