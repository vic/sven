# Phones: nix-on-droid. Only phone users live here; their homes go to the droid config.
{
  yen,
  lib,
  inputs,
  ...
}:
{
  yen.kinds.phone = {
    fields = { inherit (yen.kinds.machine.fields) environment channel system; };
    spawns.user = _: lib.filterAttrs (_: u: u.phone) yen.user;
    sinks.droid.out = yen.lib.batteries.droid.system {
      from = yen.kinds.phone.sinks.droid;
      inherit (inputs.nix-on-droid.lib) nixOnDroidConfiguration;
      pkgs = yen.helpers.pkgsOf;
    };
    sinks.homeManager.droid = yen.lib.batteries.droid.home {
      from = yen.kinds.phone.sinks.homeManager;
    };
  };
}
