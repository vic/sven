# ready-made kits: each is a module a fleet imports (`imports = [ inputs.yen.lib.kits.<name> ];`).
# A kit that needs a path from the fleet takes it as an argument: `inputs.yen.lib.kits.wireguard { root = ./vars; }`.
{
  disko = import ./disko.nix;
  facter = import ./facter.nix;
  dns = import ./dns.nix;
  wireguard = import ./wireguard.nix;
  zerotier = import ./zerotier.nix;
  sshd = import ./sshd.nix;
  users = import ./users.nix;
  emergency-access = import ./emergency-access.nix;
  borg = import ./borg.nix;
  wifi = import ./wifi.nix;
  remote-builders = import ./remote-builders.nix;
  nix-cache = import ./nix-cache.nix;
  monitoring = import ./monitoring.nix;
  postgres = import ./postgres.nix;
  base = import ./base.nix;
  homelab = import ./homelab.nix;
}
