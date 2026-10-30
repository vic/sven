# /etc/hosts and ssh known_hosts of every other machine, from sink `from` (reduce entries): each element
# `{ name; addr; key ? null; }` (the `mesh` battery). A machine never lists itself.
#   yen.kinds.fleet.sinks.peers.reduce = yen.lib.reduce.entries;
#   yen.aspects.peers = { at = yen.kinds.host; nixos = nixos.hosts { from = yen.kinds.fleet.sinks.peers; }; };
{ from }:
(import ../mesh.nix) {
  inherit from;
  build =
    peers:
    let
      b = builtins;
    in
    {
      networking.hosts = b.zipAttrsWith (_: ns: b.concatLists ns) (
        map (p: { ${p.addr} = [ p.name ]; }) peers
      );
      programs.ssh.knownHosts = b.listToAttrs (
        map (p: {
          inherit (p) name;
          value = {
            hostNames = [
              p.name
              p.addr
            ];
            publicKey = p.key;
          };
        }) (b.filter (p: p.key or null != null) peers)
      );
    };
}
