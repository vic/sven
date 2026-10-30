#: lib.batteries.flake-file.write :: { from; inputs; lib; pkgs; modules ? ; } -> out value -- flake.nix from the inputs each aspect declares, with its write package and check
# flake.nix from sink `from` with github:vic/flake-file: each aspect declares the inputs it uses next to the code
# that uses them. `from` reduces with merge. The value of the sink's `out` key: `packages.<system>.write-flake` and
# `checks.<system>.flake-file` (the committed flake.nix must match).
#   yen.kinds.repo.sinks.flake-file = { reduce = yen.lib.reduce.merge; out = flake-file.write {
#     from = yen.kinds.repo.sinks.flake-file; inherit (inputs.nixpkgs) lib; inherit inputs pkgs; }; };
{
  from,
  lib,
  inputs,
  pkgs,
  modules ? [ ],
}:
{ sinks, ... }:
let
  e = lib.evalModules {
    specialArgs = { inherit inputs; }; # flake-file reads `inputs.self` (the files it checks)
    modules = [
      inputs.flake-file.flakeModules.flake
      { flake-file = sinks.${from.__sink}; }
    ]
    ++ modules;
  };
  system = pkgs.stdenv.hostPlatform.system;
in
{
  packages.${system}.write-flake = e.config.flake-file.apps.write-flake pkgs;
  checks.${system}.flake-file = e.config.flake-file.check-flake-file pkgs;
}
