#: lib.kits.homelab :: module -- bundle homelab: one server and nodes, with base, a wireguard network, backups, monitoring and dns
# Roles `server` (exactly 1) and `node`, both with the interface of base (`device`, `layout`, `authorizedKeys`,
# `hardware`) and `prefix` (the wireguard network); settings may be a function of the machine. It adds, from its own role
# `at`: base on both roles, wireguard (server controller, nodes peers), borg (server backs up, nodes are clients),
# monitoring (server scrapes, nodes export) and dns on the server. The engine adds one level, so the assemblies that
# base and borg add are listed here too. Import the kits it uses (base, disko, facter, sshd, emergency-access,
# wireguard, borg, monitoring, dns) as well; a machine needs the field `addr`.
#   imports = [ inputs.yen.lib.kits.homelab ];
{ yen, lib, ... }:
let
  inherit (yen.lib) holds;
  iface = {
    prefix.type = lib.types.str;
  }
  // yen.kit.base.roles.default.interface;
  # the settings of the role that holds the machine, restricted to names
  of =
    a: names: m:
    let
      r = if holds a.roles.server.at m then a.roles.server else a.roles.node;
      s = r.settings or { };
    in
    lib.intersectAttrs (lib.genAttrs names (_: null)) (if lib.isFunction s then s m else s);
  # an assembly of kit k, and the assemblies that k adds for it (the engine adds one level)
  put =
    k: name: asm:
    {
      ${name} = asm // {
        kit = k;
      };
    }
    // k.adds (asm // { inherit name; });
in
{
  yen.kit.homelab = {
    roles = lib.genAttrs [ "server" "node" ] (_: {
      interface = iface;
    });
    constraints.roles.server = {
      min = 1;
      max = 1;
    };
    adds =
      a:
      let
        n = a.name;
        s = a.roles.server;
        d = a.roles.node;
        both = [
          s.at
          d.at
        ];
      in
      put yen.kit.base "${n}-base" {
        roles.default = {
          at = both;
          settings = of a [
            "device"
            "layout"
            "authorizedKeys"
            "hardware"
          ];
        };
      }
      // {
        "${n}-wg" = {
          kit = yen.kit.wireguard;
          roles = {
            controller = {
              inherit (s) at;
              settings = of a [ "prefix" ];
            };
            peer = {
              inherit (d) at;
              settings = of a [ "prefix" ];
            };
          };
        };
        "${n}-monitoring" = {
          kit = yen.kit.monitoring;
          roles = {
            server = { inherit (s) at; };
            exporter = { inherit (d) at; };
          };
        };
        "${n}-dns" = {
          kit = yen.kit.dns;
          roles.default = { inherit (s) at; };
        };
      }
      // put yen.kit.borg "${n}-borg" {
        roles = {
          server = { inherit (s) at; };
          client = { inherit (d) at; };
        };
      };
  };
}
