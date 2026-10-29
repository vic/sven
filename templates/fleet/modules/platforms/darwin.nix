# macOS: the darwin sink; os fans out to darwin.
{ yen, ... }:
{
  yen.kinds.mac = {
    fields = yen.kinds.machine.fields;
    spawns.user = yen.helpers.usersOn;
    sinks.darwin.out =
      { mac, darwin, ... }:
      {
        darwinConfigurations.${mac.name} = mac.channel.darwin.lib.darwinSystem {
          system = mac.system.name;
          modules = darwin;
        };
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
    darwin =
      { mac, ... }:
      {
        system.stateVersion = 6;
        system.primaryUser = if mac.system-owner != null then mac.system-owner.name else "root";
      };
  };
}
