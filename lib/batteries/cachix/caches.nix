# binary caches from sink `from`: each element `{ name; publicKey; url ? "https://<name>.cachix.org"; }`. The value of
# a key that gives a NixOS, nix-darwin or home-manager module: the same `nix.settings` in all three.
#   yen.kinds.host.sinks.caches.nixos = cachix.caches { from = yen.kinds.host.sinks.caches; };
#   yen.aspects.vix-cache = { at = yen.kinds.host; caches = { name = "vix"; publicKey = "vix.cachix.org-1:…"; }; };
{ from }:
{ sinks, ... }:
let
  b = builtins;
  cs = sinks.${from.__sink};
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
  urlOf = c: c.url or "https://${c.name}.cachix.org";
in
{
  nix.settings = {
    substituters = unique (map urlOf cs);
    trusted-public-keys = unique (map (c: c.publicKey) cs);
  };
}
