{ yen, ... }:
{
  yen.aspects.nginx = {
    at = yen.host.web;
    nixos = {
      services.nginx.enable = true;
      networking.firewall.allowedTCPPorts = [ 80 ];
    };
  };
  yen.aspects.printing = {
    at = yen.host.desk;
    nixos.services.printing.enable = true;
  };
}
