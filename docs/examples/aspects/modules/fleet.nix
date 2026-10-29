# Hosts with users. A host collects `packages`; a user has no such sink, so its packages go up to its host.
{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    spawns.user = s: lib.filterAttrs (_: u: lib.any (yen.lib.same s) u.hosts) yen.user;
    sinks.packages.out =
      { host, packages, ... }:
      {
        packages.${host.name} = packages;
      };
  };
  yen.kinds.user.fields.hosts = yen.lib.is lib.isList;

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
  yen.host.web = { };
  yen.host.db = { };
  yen.user.alice.hosts = [ yen.host.web ];
  yen.user.bob.hosts = [
    yen.host.web
    yen.host.db
  ];
}
