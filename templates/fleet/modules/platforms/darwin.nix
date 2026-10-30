# macOS: the darwin sink; os fans out to darwin.
{ yen, ... }:
{
  yen.kinds.mac = {
    fields = yen.kinds.machine.fields;
    spawns.user = yen.helpers.usersOn;
    sinks.darwin.out = yen.lib.batteries.darwin.system {
      from = yen.kinds.mac.sinks.darwin;
      darwinSystem = m: m.channel.darwin.lib.darwinSystem;
      system = m: m.system.name;
    };
    sinks.os.darwin =
      { os, ... }:
      {
        imports = os;
      };
  };
  # what every nix-darwin system needs: a stateVersion, and the user that user-level options (dock, defaults) apply to
  yen.aspects.darwin-base = {
    at = yen.kinds.mac;
    darwin.system.stateVersion = 6;
  };
  yen.aspects.darwin-primary-user = {
    at = yen.kinds.mac;
    darwin = yen.lib.batteries.darwin.primary-user { user = m: m.system-owner; };
  };
}
