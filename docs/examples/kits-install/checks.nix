{
  result,
  variant,
  eq,
  yes,
  no,
  ...
}:
{
  disko-devices = {
    t1 = eq (result.flake.config.lb.disko.devices.disk.main.device) ("/dev/sda");
    t2 = yes (result.flake.config.nas.disko.devices.disk ? d1);
    t3 = yes (result.flake.config.web.disko.devices.disk.main.content.partitions ? luks);
  };
  facter = {
    t1 = yes (
      builtins.match ".*/hardware/lb.json" (toString result.flake.config.lb.hardware.facter.reportPath)
      != null
    );
    t2 = no (result.flake.config.web ? hardware);
  };
  apps = {
    t1 =
      eq
        (builtins.filter (n: builtins.substring 0 8 n == "install-") (
          builtins.attrNames result.flake.apps.x86_64-linux
        ))
        ([
          "install-lb"
          "install-nas"
          "install-web"
        ]);
    t2 = eq (builtins.filter (n: builtins.substring 0 8 n == "rebuild-") (
      builtins.attrNames result.flake.apps.x86_64-linux
    )) ([ "rebuild-web" ]);
  };
  layout-string = eq (map (e: e.error) (variant "variants/layout-string.nix").errors) [
    "kits: disk-bad.default: setting layout is not a layout ref"
  ];
}
