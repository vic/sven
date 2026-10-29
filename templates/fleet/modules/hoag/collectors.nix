# den-hoag collectors: an aggregate is an entity. A hive has its own content (its `meta` sink) and selects its members
# with a predicate. It reads the fleet's colmena pool; it never re-evaluates a member.
{ yen, lib, ... }:
{
  yen.kinds.fleet.spawns.hive = _: yen.hive;
  yen.kinds.hive = {
    fields.environment = yen.kinds.environment;
    sinks.meta.reduce = yen.lib.reduce.merge;
    sinks.meta.out =
      {
        hive,
        meta,
        colmena,
        ...
      }:
      {
        colmenaHives.${hive.name} = {
          inherit meta;
        }
        // lib.filterAttrs (
          n: _: yen.host ? ${n} && yen.lib.same yen.host.${n}.environment hive.environment
        ) colmena;
      };
  };
  yen.hive = {
    prod.environment = yen.environment.prod;
    staging.environment = yen.environment.staging;
  };
  yen.aspects.hive-meta = {
    at = yen.kinds.hive;
    meta =
      { hive, ... }:
      {
        description = "the ${hive.name} hive";
        allowApplyAll = hive.name != "prod";
      };
  };
}
