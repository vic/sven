# network kits from yen.lib.kits: wireguard (controller lb, peers web-1 and web-2), zerotier (controller lb, moon web-1,
# peers web-2 and stage) and dns (imported in kits.nix). Public keys and ids are read from vars/per-machine.
{ yen, inputs, ... }:
let
  inherit (yen) kit host;
  inherit (yen.lib) same;
  root = ../../vars/per-machine;
  web = s: same s host.web-1 || same s host.web-2;
in
{
  imports = [
    (inputs.yen.lib.kits.wireguard { inherit root; })
    (inputs.yen.lib.kits.zerotier { inherit root; })
  ];
  yen.assembly = {
    vpn = {
      kit = kit.wireguard;
      roles = {
        controller = {
          at = host.lb;
          settings.prefix = "10.8.0.0/24";
        };
        peer = {
          at = web;
          settings.prefix = "10.8.0.0/24";
        };
      };
    };
    overlay = {
      kit = kit.zerotier;
      roles = {
        controller.at = host.lb;
        moon.at = host.web-1;
        peer.at = s: same s host.web-2 || same s host.stage;
      };
    };
  };
}
