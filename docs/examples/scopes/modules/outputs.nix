# The flake gives the scope ids: `yen.lib.graph` is readable inside the fleet.
{ yen, ... }:
{
  yen.kinds.fleet.sinks.out.reduce = yen.lib.reduce.merge;
  yen.flake = { out, ... }: out;
  yen.aspects.tree = {
    at = yen.kinds.fleet;
    out.scopes = map (s: s.id) yen.lib.graph.scopes;
  };
}
