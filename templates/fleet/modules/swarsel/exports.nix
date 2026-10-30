# swarsel exports: aspects used outside yen. An export scope never builds a machine;
# what lands on it becomes `nixosModules.<name>` for other flakes (Den: `moduleOf`, "change needed").
{ yen, ... }:
{
  yen.kinds.fleet.spawns.export = _: yen.export;
  yen.kinds.export.sinks.os.out = yen.lib.batteries.exports.modules {
    from = yen.kinds.export.sinks.os;
    output = "nixosModules";
  };
  yen.export.base = { };
  yen.aspects.motd.at = [ yen.export.base ];
  yen.aspects.dev.at = [ yen.export.base ];
}
