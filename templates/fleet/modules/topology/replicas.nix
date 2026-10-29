# A relation kind: a replica is a (db, region) pair; the fleet spawns only matching pairs.
{ yen, lib, ... }:
{
  yen.kinds.db.fields.zone = lib.types.str;
  yen.kinds.region.fields.zone = lib.types.str;
  yen.kinds.replica.fields = {
    db = yen.kinds.db;
    region = yen.kinds.region;
  };
  yen.db = {
    primary.zone = "eu";
    backup.zone = "us";
  };
  yen.region.eu.zone = "eu";
  yen.replica = {
    r1 = {
      db = yen.db.primary;
      region = yen.region.eu;
    };
    r2 = {
      db = yen.db.backup;
      region = yen.region.eu;
    };
  };
}
