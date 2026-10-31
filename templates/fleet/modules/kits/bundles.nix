# bundles from yen.lib.kits: one homelab over the app hosts (app-1 serves, app-2 and app-3 are nodes). It adds base
# (disko, facter, sshd, emergency-access), wireguard, borg, monitoring and dns assemblies from its own two roles.
{ yen, inputs, ... }:
let
  inherit (yen) host;
  k = inputs.yen.lib.kits;
  shared = {
    device = "/dev/sda";
    layout = yen.layout.single-ext4;
    authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBLabKeyNotReal admin" ];
    hardware = ../../hardware;
    prefix = "10.9.0.0/24";
  };
in
{
  imports = [
    k.homelab
    k.base
    k.facter
  ]; # disko, sshd, emergency-access, wireguard, borg, monitoring and dns are imported by the other kit files
  yen.assembly.lab = {
    kit = yen.kit.homelab;
    roles = {
      server = {
        at = host.app-1;
        settings = shared;
      };
      node = {
        at = [
          host.app-2
          host.app-3
        ];
        settings = shared;
      };
    };
  };
}
