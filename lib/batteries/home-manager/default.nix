# home-manager: standalone homes, homes inside machines.
{
  system = import ./system.nix;
  into-host = import ./into-host.nix;
  module = import ./module.nix;
}
