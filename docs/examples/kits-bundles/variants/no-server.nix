# a homelab with nodes and no machine for the server role
{ yen, ... }:
{
  yen.assembly.lab0 = {
    kit = yen.kit.homelab;
    roles = {
      server = {
        at = _: false;
        settings = import ../shared.nix yen;
      };
      node = {
        at = yen.host.web;
        settings = import ../shared.nix yen;
      };
    };
  };
}
