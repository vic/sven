# open ports from sink `from`: each element a port number (tcp), or `{ tcp ? [ ]; udp ? [ ]; }`. Any aspect at the
# host or under it gives the ports it needs; the firewall is built once.
#   yen.kinds.host.sinks.ports.nixos = nixos.firewall { from = yen.kinds.host.sinks.ports; };
{ from }:
{ sinks, ... }:
let
  b = builtins;
  ps = sinks.${from.__sink};
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
  of =
    k:
    unique (
      b.concatMap (p: if b.isInt p then (if k == "tcp" then [ p ] else [ ]) else p.${k} or [ ]) ps
    );
in
{
  networking.firewall = {
    allowedTCPPorts = of "tcp";
    allowedUDPPorts = of "udp";
  };
}
