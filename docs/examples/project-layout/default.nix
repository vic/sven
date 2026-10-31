# Without flakes: every query of the fleet. Pin the sources with npins, niv or fetchTarball.
{
  yen ? builtins.fetchTarball "https://github.com/vic/yen/archive/main.tar.gz",
  nixpkgs ? builtins.fetchTarball "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz",
  import-tree ? import (
    builtins.fetchTarball "https://github.com/denful/import-tree/archive/main.tar.gz"
  ),
}:
(import yen).lib.eval {
  imports = [ (import-tree ./modules) ];
  inputs = { inherit nixpkgs; };
  lib = import "${nixpkgs}/lib";
}
