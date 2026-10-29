{ yen, lib, ... }:
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.fields = {
    addr = lib.types.str;
    form = lib.types.enum [
      "server"
      "laptop"
    ];
  };

  yen.fleet.main = { };
  yen.host.web = {
    addr = "10.0.0.1";
    form = "server";
  };
  yen.host.db = {
    addr = "10.0.0.2";
    form = "server";
  };
  yen.host.thinkpad = {
    addr = "10.0.0.50";
    form = "laptop";
  };
  yen.aspects.desktop.at = s: (s.form or null) == "laptop";
  yen.aspects.postgres.at = yen.host.db;
  yen.flake = { out, ... }: out;
}
