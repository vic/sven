# a cache with two servers: nix-cache allows one
{ yen, ... }:
{
  yen.assembly.cache2 = {
    kit = yen.kit.nix-cache;
    roles.server = {
      at = [
        yen.host.nas
        yen.host.lb
      ];
    };
  };
}
