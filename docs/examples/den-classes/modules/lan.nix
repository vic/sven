# A class that lands under a path: forward's intoPath. `lan` content goes to networking.interfaces.<host.lan>.
# Features add routes to the LAN without knowing the interface name.
{ yen, lib, ... }:
{
  yen.kinds.host.sinks.lan.nixos =
    { host, lan, ... }:
    {
      networking.interfaces.${host.lan} = lib.mkMerge lan;
    };

  yen.aspects.subnet-a = {
    at = yen.kinds.host;
    lan.ipv4.routes = [
      {
        address = "192.168.2.0";
        prefixLength = 24;
        via = "192.168.1.1";
      }
    ];
  };
  yen.aspects.server-address = {
    at = yen.host.server;
    lan.ipv4.addresses = [
      {
        address = "10.0.0.1";
        prefixLength = 16;
      }
    ];
  };
}
