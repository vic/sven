# NixOS `config` becomes instance data, and `mkIf` becomes `at`.
{ yen, ... }:
{
  yen.fleet.main = { };
  yen.flake = { }; # no flake outputs: this page reads the eval result
  yen.host = {
    web = {
      addr = "10.0.0.1";
      firewall.enable = true;
      firewall.ports = [ 443 ];
    };
    db.addr = "10.0.0.2";
  };
  yen.user.ana.on = yen.host.web;
  yen.aspects.firewall = {
    # mkIf config.firewall.enable. `at` runs at every scope: guard with the kind, then read the field
    at = yen.lib.all [
      yen.kinds.host
      (s: s.firewall.enable)
    ];
    nixos =
      { host, ... }:
      {
        networking.firewall.allowedTCPPorts = host.firewall.ports;
      };
  };
}
