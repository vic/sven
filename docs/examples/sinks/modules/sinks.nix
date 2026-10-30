# A sink collects elements and reduces them. `of` checks each element.
{ yen, lib, ... }:
let
  inherit (yen.lib.reduce)
    list
    set
    flat
    one
    merge
    entries
    ;
  sorted = es: {
    value = lib.sort (a: b: a < b) (map (e: e.value) es);
    errors = [ ];
  }; # your own reduce
in
{
  yen.kinds.host.sinks = {
    motd = {
      reduce = list;
      of = lib.types.str;
    };
    ports = {
      reduce = set;
      of = lib.types.port;
    };
    packages.reduce = flat;
    admin.reduce = one;
    nginx.reduce = merge;
    owners.reduce = entries;
    groups.reduce = sorted;
  };
  # every sink of a host, read as args, to one flake output
  yen.aspects.report = {
    at = yen.kinds.host;
    out =
      {
        host,
        motd,
        ports,
        packages,
        admin,
        nginx,
        owners,
        groups,
        ...
      }:
      {
        ${host.name} = {
          inherit
            motd
            ports
            packages
            admin
            nginx
            groups
            ;
          owners = map (e: e.from.kind) owners;
        };
      };
  };
}
