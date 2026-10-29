# Kinds: typed data. `office` is the root: nothing spawns it.
{ yen, lib, ... }:
{
  yen.kinds.office = {
    spawns.machine = _: yen.machine; # scopes: every machine lives in the office
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.machine = {
    fields.owner = lib.types.str;
    sinks.packages.reduce = yen.lib.reduce.set; # sinks: where elements go
    sinks.packages.out =
      { machine, packages, ... }:
      {
        inventory.${machine.name} = packages;
      };
  };

  yen.office.main = { };
  yen.machine.reception.owner = "ana";
  yen.machine.studio.owner = "bo";
  yen.flake = { out, ... }: out;
}
