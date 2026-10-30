# a cache whose server machine has no generated cache-key.pub in the vars directory
{ yen, ... }:
{
  yen.assembly.cache5 = {
    kit = yen.kit.nix-cache;
    roles = {
      server.at = yen.host.web;
      client.at = yen.host.lb;
    };
  };
}
