# A fact that only some hosts have: each Syncthing host gives its device id. The ids go up to the fleet;
# every Syncthing host reads them back and adds the others as devices.
{ yen, lib, ... }:
{
  yen.kinds.fleet.sinks.syncthing-device.reduce = yen.lib.reduce.entries; # each id with the host that gave it

  yen.aspects.syncthing = {
    at = [
      yen.host.nas
      yen.host.desk
    ];
    nixos =
      { host, syncthing-device, ... }:
      {
        services.syncthing = {
          enable = true;
          settings.devices = lib.listToAttrs (
            map (e: lib.nameValuePair e.from.name { inherit (e.value) id; }) (
              lib.filter (e: e.from.name != host.name) syncthing-device
            )
          );
        };
      };
  };
  # the ids, in each host's own file in a real fleet
  yen.aspects.nas-id = {
    at = yen.host.nas;
    syncthing-device.id = "NAS1111-1111111-1111111-1111111-1111111-1111111-1111111-1111111";
  };
  yen.aspects.desk-id = {
    at = yen.host.desk;
    syncthing-device.id = "DESK222-2222222-2222222-2222222-2222222-2222222-2222222-2222222";
  };
}
