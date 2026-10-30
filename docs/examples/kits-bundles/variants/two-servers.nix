# a homelab with two servers: exactly one is allowed
{ yen, ... }:
{
  yen.assembly.lab2 = {
    kit = yen.kit.homelab;
    roles = {
      server = {
        at = [
          yen.host.nas
          yen.host.lb
        ];
        settings = import ../shared.nix yen;
      };
      node = {
        at = yen.host.web;
        settings = import ../shared.nix yen;
      };
    };
  };
}
