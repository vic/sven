# known_hosts and WireGuard peers: every other host, from its fields. No hosts list to keep in sync.
{ yen, lib, ... }:
let
  others = host: lib.filterAttrs (n: _: n != host.name) yen.host;
in
{
  yen.aspects.mesh = {
    at = yen.kinds.host;
    nixos =
      { host, ... }:
      {
        programs.ssh.knownHosts = lib.mapAttrs (n: h: {
          hostNames = [ n ];
          publicKey = h.sshKey;
        }) (others host);
        networking.wireguard.interfaces.wg0 = {
          ips = [ "${host.wgIp}/24" ];
          privateKeyFile = "/var/lib/wireguard/private.key";
          peers = lib.mapAttrsToList (_: h: {
            publicKey = h.wgKey;
            allowedIPs = [ "${h.wgIp}/32" ];
          }) (others host);
        };
      };
  };
}
