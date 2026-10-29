# Guests: a microvm on a host. Its nixos forwards to the host (a key with the sink's own name goes up).
{ yen, lib, ... }:
{
  yen.kinds.guest = {
    fields = yen.kinds.machine.fields // {
      on = yen.kinds.host;
    };
    spawns.user = yen.helpers.usersOn; # no spawns.guest: no guest in a guest
    sinks = {
      nixos.nixos =
        { guest, nixos, ... }:
        {
          microvm.vms.${guest.name} = {
            pkgs = yen.helpers.pkgsOf guest;
            config.imports = nixos;
          };
        };
      inherit (yen.kinds.host.sinks)
        os
        persist
        age-secrets
        unfree
        ;
    };
  };
}
