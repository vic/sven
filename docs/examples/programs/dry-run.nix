# Validate and stage a change program. Nothing is applied.
#   nix eval --impure --json --file dry-run.nix --argstr program programs/new-cache.json
{
  program,
  yen ? builtins.fetchTarball "https://github.com/vic/yen/archive/main.tar.gz",
  nixpkgs ? builtins.fetchTarball "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz",
  import-tree ? import (
    builtins.fetchTarball "https://github.com/denful/import-tree/archive/main.tar.gz"
  ),
}:
(import yen).lib.program.dryRun {
  base = {
    imports = [ (import-tree ./modules) ];
    lib = import "${nixpkgs}/lib";
    yen.sinks.lib = { };
  };
  prog = builtins.fromJSON (builtins.readFile (./. + "/${program}"));
}
