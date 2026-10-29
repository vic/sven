# The root kind: nothing spawns it. Its sinks are the flake outputs and the fleet-wide pools.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib.reduce) merge;
in
{
  yen.kinds.fleet = {
    spawns = {
      environment = _: yen.environment;
      system = _: yen.system;
      home = _: lib.filterAttrs (_: h: h.on == null) yen.home; # homes on a host live under it (den#739)
      replica = _: lib.filterAttrs (_: r: r.db.zone == r.region.zone) yen.replica; # a relation kind: only matching pairs
    };
    sinks = {
      out.reduce = merge;
      vars = {
        reduce = merge;
        out =
          { vars, ... }:
          {
            inherit vars;
          };
      };
      colmena = {
        reduce = merge;
        out =
          { colmena, ... }:
          {
            colmenaHive = inputs.colmena.lib.makeHive (
              { meta.nixpkgs = inputs.nixpkgs.legacyPackages.x86_64-linux; } // colmena
            );
          };
      };
      overlays = { }; # machines read it
      records = {
        of = lib.types.attrsOf lib.types.str;
        reduce = merge;
      }; # every machine's A record; prod reads it
      scrape.of = yen.lib.is (v: lib.isString (v.job or null) && lib.isString (v.target or null));
    };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
