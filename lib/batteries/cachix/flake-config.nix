#: lib.batteries.cachix.flake-config :: { from; } -> key value -- the same caches as flake.nix nixConfig, for a flake-file sink
# the same caches as flake.nix `nixConfig` (extra-substituters, extra-trusted-public-keys): the value of a key that
# gives to a flake-file sink, so `nix` asks to trust them when it evaluates the flake.
#   flake-file = cachix.flake-config { from = yen.kinds.fleet.sinks.caches; };
{ from }:
{ sinks, ... }:
let
  b = builtins;
  cs = sinks.${from.__sink};
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
in
{
  nixConfig = {
    extra-substituters = unique (map (c: c.url or "https://${c.name}.cachix.org") cs);
    extra-trusted-public-keys = unique (map (c: c.publicKey) cs);
  };
}
