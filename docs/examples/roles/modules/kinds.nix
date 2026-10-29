# Machines carry facts. No host file names its roles: the facts decide.
{ yen, lib, ... }:
let
  inherit (yen.lib) opt is;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.fields = {
    form = lib.types.enum [
      "server"
      "laptop"
      "desktop"
    ];
    gpu = opt (lib.types.enum [
      "none"
      "nvidia"
      "amd"
    ]) "none";
    labels = opt (is (v: lib.isList v && lib.all lib.isString v)) [ ];
  };

  yen.fleet.main = { };
  yen.host.rack-1 = {
    form = "server";
    labels = [ "ci-runner" ];
  };
  yen.host.rack-2.form = "server";
  yen.host.thinkpad.form = "laptop";
  yen.host.tower = {
    form = "desktop";
    gpu = "nvidia";
  };
  yen.flake = { out, ... }: out;
}
