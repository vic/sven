# known_hosts and WireGuard peers: every other host, from its fields. No hosts list to keep in sync.
# Other hosts' data comes through a tree request, so each read is an edge `stage` can see.
{ yen, lib, ... }:
let
  all.instances = yen.kinds.host; # a tree request: every host, with its data
in
{
  yen.aspects.mesh = {
    at = yen.kinds.host;
    cycle =
      { tree, scope, ... }:
      let
        others = lib.filter (h: !yen.lib.same h scope) (lib.head (tree.select all));
      in
      {
        tree = [ all ];
        nixos = [
          {
            programs.ssh.knownHosts = lib.listToAttrs (
              map (h: {
                name = h.name;
                value = {
                  hostNames = [ h.name ];
                  publicKey = h.sshKey;
                };
              }) others
            );
            networking.wireguard.interfaces.wg0 = {
              ips = [ "${scope.wgIp}/24" ];
              privateKeyFile = "/var/lib/wireguard/private.key";
              peers = map (h: {
                publicKey = h.wgKey;
                allowedIPs = [ "${h.wgIp}/32" ];
              }) others;
            };
          }
        ];
      };
  };
}
