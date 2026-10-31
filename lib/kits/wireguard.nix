#: lib.kits.wireguard :: { root; } -> module -- a wireguard network: one controller, peers; addresses from battery `addresses`, keys from generators
# `root`: where public keys are read from. Interface: `prefix` (IPv4 /16 to /24), `port` (51820). Members take addresses in
# member order (battery `addresses`), export the public key ref and key generator; the private key is a path only.
#   imports = [ (inputs.yen.lib.kits.wireguard { root = ../../vars/per-machine; }) ];
{ root }:
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  pub = yen.lib.batteries.vars.public-value { inherit root; };
  members = all [
    yen.kinds.member
    (s: same (s.kit or null) yen.kit.wireguard)
  ];
  key = a: "wg-${a.name}"; # a generator name
  iface = {
    prefix.type = lib.types.str;
    port = {
      type = lib.types.port;
      default = 51820;
    };
  };
  pk = x: pub x.machine.name "from-exports" x.value.public null; # null: the public file is missing
  inherit (import ./_wireguard-check.nix { inherit yen lib pk; }) alloc check;
in
{
  yen.kit.wireguard = {
    roles = lib.genAttrs [ "controller" "peer" ] (_: {
      interface = iface;
    });
    constraints.roles.controller = {
      min = 1;
      max = 1;
    };
    exports = [
      "prefix"
      "public"
      "generators"
    ];
  };
  yen.aspects.wireguard-keys = {
    at = members;
    exports =
      { member, scope, ... }:
      {
        inherit (member.settings) prefix;
        public = "${key member.assembly}.pub"; # a file of generator from-exports
        generators.${key member.assembly} = {
          deploy = [ scope.parent ];
          files."${key member.assembly}.key".secret = true;
          files."${key member.assembly}.pub".secret = false;
        };
      };
  };
  yen.aspects.wireguard-addresses = {
    at = yen.kinds.fleet;
    errors =
      { exports, ... }:
      map (e: e.error) (
        lib.concatMap (es: lib.optionals (same (lib.head es).kit yen.kit.wireguard) (check es)) (
          lib.attrValues (lib.groupBy (x: x.assembly.name) exports)
        )
      );
  };
  yen.aspects.wireguard-net = {
    at = members;
    nixos =
      {
        member,
        scope,
        exports,
        ...
      }:
      let
        me = scope.parent.name;
        es = lib.filter (x: same x.assembly member.assembly) exports;
        ips = (alloc es).value;
        ctl = member.role == "controller";
        peer =
          x:
          {
            publicKey = pk x;
            allowedIPs = [ (if ctl then "${ips.${x.machine.name}}/32" else member.settings.prefix) ];
          }
          // lib.optionalAttrs (!ctl) { endpoint = "${x.machine.addr}:${toString member.settings.port}"; };
      in
      lib.optionalAttrs (ips ? ${me}) {
        networking.wireguard.interfaces.${member.assembly.name} = {
          ips = [ "${ips.${me}}/32" ];
          privateKeyFile = "/run/secrets/vars/from-exports/${key member.assembly}.key"; # a path only
          peers = map peer (
            lib.filter (x: x.machine.name != me && (ctl || x.role == "controller") && pk x != null) es
          );
        }
        // lib.optionalAttrs ctl { listenPort = member.settings.port; };
      };
  };
}
