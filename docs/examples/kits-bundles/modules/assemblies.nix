# A bundle is a kit whose assemblies make more assemblies: one `homelab` assembly names the server and the nodes,
# and the base, wireguard, borg, monitoring and dns assemblies follow from those two roles. Import the kits it uses.
{ yen, inputs, ... }:
let
  inherit (yen) host kit;
  k = inputs.yen.lib.kits;
  shared = import ../shared.nix yen;
in
{
  imports = [
    k.homelab
    k.base
    k.disko
    k.facter
    k.sshd
    k.emergency-access
    (k.wireguard { root = ../vars; })
    k.borg
    k.monitoring
    k.dns
  ];
  yen.host = {
    lb.addr = "10.0.0.1";
    web.addr = "10.0.0.2";
    nas.addr = "10.0.0.3";
  };
  yen.assembly.lab = {
    kit = kit.homelab;
    roles = {
      server = {
        at = host.nas;
        settings = shared // {
          device = "/dev/sda /dev/sdb";
          layout = yen.layout.zfs-mirror;
        };
      };
      node = {
        at = [
          host.lb
          host.web
        ];
        settings = shared;
      };
    };
  };
}
