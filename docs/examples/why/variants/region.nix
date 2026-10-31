# `facts.host` and `host.region` were derived here by Yen,
# it follows your own domain definitions.
{ yen, ... }:
let
  inherit (yen.lib) maybe same;
  inherit (yen.facts) host;
in
{
  yen.fleet.main = { };
  yen.kinds.fleet.spawns.region = _: yen.region;
  yen.kinds.region.spawns.host =
    s:
    builtins.removeAttrs yen.host (
      builtins.filter (n: !same yen.host.${n}.region s) (builtins.attrNames yen.host)
    );
  yen.kinds.host.fields = {
    region = yen.kinds.region;
    db = maybe yen.kinds.host;
  };

  yen.region.eu = { };
  yen.region.us = { };
  yen.host.db.region = yen.region.us;
  yen.host.api = {
    region = yen.region.eu;
    db = yen.host.db;
  };

  yen.invariants.db-same-region =
    {
      H,
      D,
      R,
    }:
    {
      bad = H;
      pos = [
        (host.db H D)
        (host.region H R)
      ]; # H uses D as its database, and lives in region R
      neg = [ (host.region D R) ]; # and D does not
    };
}
