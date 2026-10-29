# A root emission: the overlay goes to the fleet's `overlays` pool; every machine reads it. A wrapped `final: prev:`.
{ yen, inputs, ... }:
{
  yen.aspects.unstable-overlay = {
    at = yen.fleet.main;
    overlays =
      { ... }:
      final: prev: {
        inherit (inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}) helix;
      };
  };
}
