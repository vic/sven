# The diamond: nginx is reached directly and through `status` (web-1, stage). It lands once per scope.
{ yen, lib, ... }:
{
  yen.aspects.nginx = {
    at = [
      yen.host.web-1
      yen.host.web-2
      yen.host.stage
      yen.aspects.status
    ];
    nixos.services.nginx.enable = true;
    backends = { host, ... }: host.addr; # goes up to the environment
    persist = "/var/lib/nginx";
    tags = "web";
  };
  yen.aspects.status = {
    at = [
      yen.host.web-1
      yen.host.stage
    ];
    nixos.services.nginx.virtualHosts.status.locations."/".return = "200 ok";
  };
  yen.aspects.http-port = {
    at = yen.aspects.nginx;
    nixos.networking.firewall.allowedTCPPorts = [ 80 ];
  };
  yen.aspects.haproxy = {
    at = yen.host.lb;
    nixos =
      { backends, ... }:
      {
        services.haproxy.enable = true;
        services.haproxy.config = lib.concatMapStrings (a: "  server ${a} ${a}:80 check\n") backends;
      };
  };
  yen.aspects.desktop = {
    at = yen.host.stage;
    nixos.services.xserver.enable = true;
  };
  yen.aspects.dock = {
    at = yen.kinds.mac;
    darwin.system.defaults.dock.autohide = true;
  };
  yen.aspects.docker = {
    at = yen.lib.all [
      yen.helpers.linux
      (yen.lib.has yen.user.bob)
    ];
    nixos.virtualisation.docker.enable = true;
    persist = "/var/lib/docker";
  };
}
