# Each aspect says where it is active. `entries` keeps the giving scope with each value.
{ yen, lib, ... }:
{
  yen.kinds.fleet.sinks.seen = {
    reduce = yen.lib.reduce.entries;
    out =
      { seen, ... }:
      {
        active = lib.mapAttrs (_: es: map (e: e.from.name) es) (lib.groupBy (e: e.value) seen);
      };
  };
  yen.flake = { out, ... }: out;
  yen.kinds.fleet.sinks.out.reduce = yen.lib.reduce.merge;
  yen.aspects = lib.genAttrs [ "builder" "cuda" "tiny" "vm-tools" "vm-host" "monitored" ] (a: {
    seen = { scope, ... }: a;
  }); # a function: one element per scope
}
