# sini mesh family (vault, thunderbolt, ollama, nix-builders): every host in an environment gives one record;
# each host reads its environment's records and drops its own. The filter lives with the reader.
{ yen, lib, ... }:
let
  peersOf = host: es: lib.filter (e: !(yen.lib.same e.from host)) es;
in
{
  yen.kinds.environment.sinks.mesh-peers.reduce = yen.lib.reduce.entries;
  yen.kinds.machine.fields.builder = yen.lib.opt lib.types.bool false;
  yen.host.web-1.builder = true;
  yen.aspects.mesh = {
    at = yen.lib.all [
      yen.kinds.host
      (s: !s.minimal)
    ];
    mesh-peers =
      { host, ... }:
      {
        inherit (host) addr builder;
      };
    nixos =
      { host, mesh-peers, ... }:
      let
        peers = peersOf host mesh-peers;
      in
      {
        networking.wireguard.interfaces.mesh = {
          ips = [ "${host.addr}/32" ];
          privateKeyFile = "/run/agenix/wg-mesh"; # a path only: the key never enters the store
          peers = map (e: {
            publicKey = builtins.hashString "sha256" e.from.name;
            allowedIPs = [ "${e.value.addr}/32" ];
            endpoint = "${e.value.addr}:51820";
          }) peers;
        };
        nix.buildMachines = map (e: {
          hostName = e.value.addr;
          system = "x86_64-linux";
        }) (lib.filter (e: e.value.builder) peers);
      };
  };
}
