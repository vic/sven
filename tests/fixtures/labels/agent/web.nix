{ yen, ... }:
{
  yen.aspects.web.nixos.networking.firewall.allowedTCPPorts = [ 80 ]; # the agent touches the same aspect
  yen.aspects.cache = {
    at = yen.kinds.host;
    nixos.services.redis.servers.a.enable = true;
  };
}
