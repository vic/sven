# The nix blocks of an issue, evaluated as one yen fleet: each block-N.nix in `blocks` is one module.
# CI: nix-instantiate --eval --strict --json --restrict-eval -I yen=… -I nixpkgs=… -I blocks=… \
#       --expr 'import ./docs/issue/eval.nix { yen = <yen>; nixpkgs = <nixpkgs>; blocks = <blocks>; }'
{
  yen,
  nixpkgs,
  blocks,
}:
let
  S = (import yen).lib;
  files = map (f: blocks + "/${f}") (
    builtins.sort builtins.lessThan (
      builtins.filter (f: builtins.match "block-[0-9]+\\.nix" f != null) (
        builtins.attrNames (builtins.readDir blocks)
      )
    )
  );
  r = S.eval {
    imports = files;
    _module.args.lib = import (nixpkgs + "/lib");
  };
in
S.jsonSafe {
  modules = builtins.length files;
  inherit (r) errors undefined;
  scopes = map (s: s.id) r.scopes;
  active = builtins.mapAttrs (_: v: builtins.filter (id: v.${id}) (builtins.attrNames v)) r.active;
  check = { inherit (r.check) ok violations incomplete; };
}
