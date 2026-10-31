# Stage a change file against the fleet. Nothing is applied.
#   nix eval --impure --json --file stage.nix --argstr change changes/desktop-on-web.json
{
  change,
  grant ? null, # where the change may reach: yen.lib.grant { scopes = [ { kind = "host"; name = "db"; } ]; }
  rejected ? [ ], # sha256 of changes refused before
  yen ? builtins.fetchTarball "https://github.com/vic/yen/archive/main.tar.gz",
  nixpkgs ? builtins.fetchTarball "https://nixos.org/channels/nixos-25.05/nixexprs.tar.xz",
  import-tree ? import (
    builtins.fetchTarball "https://github.com/denful/import-tree/archive/main.tar.gz"
  ),
}:
let
  base = {
    imports = [ (import-tree ./modules) ];
    lib = import "${nixpkgs}/lib";
    yen.sinks.lib = { };
  };
  s = (import yen).lib.stage {
    inherit base grant rejected;
    change = builtins.fromJSON (builtins.readFile (./. + "/${change}"));
  };
in
removeAttrs s [ "render" ]
