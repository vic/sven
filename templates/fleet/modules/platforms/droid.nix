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
    sinks.droid.out =
      { phone, droid, ... }:
      {
        nixOnDroidConfigurations.${phone.name} = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
          pkgs = yen.helpers.pkgsOf phone;
          modules = droid;
        };
      };
    sinks.homeManager.droid =
      { homeManager, ... }:
      {
        home-manager.config.imports = homeManager;
      };
  };
}
