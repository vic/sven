# Ports, peers and builders: sinks you name, NixOS values from batteries.
{ yen, lib, ... }:
let
  nixos = yen.lib.batteries.nixos;
  str = lib.types.str;
in
{
  yen.kinds.host = {
    fields = {
      addr = str;
      sshKey = str;
    };
    sinks.ports.nixos = nixos.firewall { from = yen.kinds.host.sinks.ports; };
  };
  # every host gives a peer record and a builder record to the fleet; each host reads the others'
  yen.kinds.fleet.sinks = {
    peers.reduce = yen.lib.reduce.entries;
    builders.reduce = yen.lib.reduce.entries;
  };
  yen.aspects.peer = {
    at = yen.kinds.host;
    peers =
      { host, ... }:
      {
        inherit (host) name addr;
        key = host.sshKey;
      };
    builders =
      { host, ... }:
      {
        hostName = host.addr;
        system = "x86_64-linux";
        maxJobs = 4;
      };
    nixos = nixos.hosts { from = yen.kinds.fleet.sinks.peers; };
  };
  yen.aspects.builds = {
    at = yen.kinds.host;
    nixos = nixos.remote-builders { from = yen.kinds.fleet.sinks.builders; };
  };
  yen.aspects.ssh = {
    at = yen.kinds.host;
    ports = 22;
    nixos.services.openssh.enable = true;
  };
  yen.aspects.dns = {
    at = yen.host.nas;
    ports = {
      tcp = [ 53 ];
      udp = [ 53 ];
    };
  };
}
