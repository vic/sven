# den-hoag collectors: an aggregate is an entity. A hive has its own content (its `meta` sink) and selects its members
# with a predicate. It reads the fleet's colmena pool; it never re-evaluates a member.
{ yen, lib, ... }:
{
  yen.kinds.fleet.spawns.hive = _: yen.hive;
  # each host gives its environment at the fleet: a hive reads its members there, so the read is an edge
  yen.kinds.fleet.sinks.host-envs.reduce = yen.lib.reduce.entries;
  yen.aspects.host-envs = {
    at = yen.kinds.host;
    host-envs = { host, ... }: host.environment;
  };
  yen.kinds.hive = {
    fields.environment = yen.kinds.environment;
    sinks.meta.reduce = yen.lib.reduce.merge;
    sinks.meta.out =
      {
        hive,
        meta,
        colmena,
        host-envs,
        ...
      }:
      {
        colmenaHives.${hive.name} = {
          inherit meta;
        }
        // lib.filterAttrs (
          n: _:
          yen.host ? ${n} && lib.any (e: e.from.name == n && yen.lib.same e.value hive.environment) host-envs
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
