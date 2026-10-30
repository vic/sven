# Paths that survive a reboot, from any feature (impermanence), and hardware from a facter report where one exists.
{ yen, inputs, ... }:
let
  nixos = yen.lib.batteries.nixos;
in
{
  yen.kinds.host.sinks.persist.nixos = nixos.persist { from = yen.kinds.host.sinks.persist; };
  yen.aspects.impermanence = {
    at = yen.kinds.host;
    nixos.imports = [ inputs.impermanence.nixosModules.impermanence ];
  };
  yen.aspects.ssh-state = {
    at = yen.kinds.host;
    persist.files = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
  yen.aspects.ana-state = {
    at = yen.user.ana; # from a user: up to each of her hosts
    persist = "/home/ana/.local/share";
  };
  # facter: only hosts with a report under modules/<host>/
  yen.aspects.facter = {
    at = s: builtins.pathExists (./. + "/${s.name}/facter.json");
    nixos = nixos.facter {
      report = h: ./. + "/${h.name}/facter.json";
      module = inputs.nixos-facter-modules.nixosModules.facter;
    };
  };
}
