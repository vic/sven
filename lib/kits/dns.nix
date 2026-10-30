#: lib.kits.dns :: module -- records for every endpoint that kits export: the `exports` sink read into one cname per endpoint
# The kit has one role, `default`. It reads the `exports` sink of the fleet, so any kit that lists `endpoints` among its
# exports gets a record per endpoint.
#   imports = [ inputs.yen.lib.kits.dns ];
{ yen, lib, ... }:
{
  yen.kit.dns.roles.default = { };
  yen.aspects.kit-dns = {
    at = yen.kinds.fleet;
    out =
      { exports, ... }:
      {
        cnames = lib.concatMap (
          x:
          map (e: {
            name = e;
            target = x.machine.name;
          }) (x.value.endpoints or [ ])
        ) exports;
      };
  };
}
