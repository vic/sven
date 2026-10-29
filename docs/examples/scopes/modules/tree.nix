# `spawns.<kind>` gives the children of a scope: a function of the parent scope.
{ yen, lib, ... }:
let
  inherit (yen.lib) same is;
in
{
  yen.kinds.fleet.spawns.environment = _: yen.environment;
  yen.kinds.environment.spawns.host = s: lib.filterAttrs (_: h: same h.environment s) yen.host;
  yen.kinds.host = {
    fields.environment = yen.kinds.environment;
    spawns.user = s: lib.filterAttrs (_: u: lib.any (same s) u.hosts) yen.user;
  };
  yen.kinds.user.fields.hosts = is lib.isList; # refs to the hosts the user logs in to

  yen.fleet.main = { };
}
