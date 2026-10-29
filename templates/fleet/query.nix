# The fleet as sven queries, outside the flake: the same module flake.nix gives mkFlake.
# Run: nix eval --impure --file query.nix errors
let
  inputs = (builtins.getFlake "path:${toString ../..}?dir=templates/fleet").inputs; # in the sven tree: `../..` resolves
in
inputs.sven.lib.eval {
  imports = [ (inputs.import-tree ./modules) ];
  _module.args = {
    inherit inputs;
    inherit (inputs.nixpkgs) lib;
  };
}
