{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    fields.addr = lib.types.str;
    spawns.user = s: lib.filterAttrs (_: u: yen.lib.same u.on s) yen.user;
    sinks.packages = {
      reduce = yen.lib.reduce.set;
      out =
        { host, packages, ... }:
        {
          packages.${host.name} = packages;
        };
    };
  };
  yen.kinds.user.fields.on = yen.kinds.host;

  yen.fleet.main = { };
  yen.host.web.addr = "10.0.0.1";
  yen.user.ana.on = yen.host.web;
  yen.aspects.git = {
    at = [
      yen.kinds.host
      yen.kinds.user
    ];
    packages = "git";
  };
  yen.aspects.nginx = {
    at = yen.host.web;
    packages = "nginx";
  };
  yen.flake = { out, ... }: out;
}
