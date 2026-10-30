#: lib.kits.base :: module -- bundle base: what a new machine needs (disk, hardware report, ssh, break-glass login) in one assembly
# One role, `default`. Interface: `device` (str), `layout` (a layout ref), `authorizedKeys` (public keys), `hardware`
# (a path: the directory of `<machine>.json` nixos-facter reports). It adds one assembly each of disko, facter, sshd (a
# server on the same machines) and emergency-access. Users are left out: a user needs a name, and a name per machine
# would be a string. Import the four kits it adds (disko, facter, sshd, emergency-access) too.
#   imports = [ inputs.yen.lib.kits.base ];
{ yen, lib, ... }:
let
  pick =
    names: a:
    let
      s = a.roles.default.settings or { };
    in
    m: lib.intersectAttrs (lib.genAttrs names (_: null)) (if lib.isFunction s then s m else s);
in
{
  yen.kit.base = {
    roles.default.interface = {
      device.type = lib.types.str;
      layout.type = yen.kinds.layout // {
        description = "layout ref";
      };
      authorizedKeys.type = lib.types.listOf lib.types.str;
      hardware.type = lib.types.path;
    };
    # a kit that needs others: one assembly of each, on the machines of the base's role
    adds = a: {
      "${a.name}-disko" = {
        kit = yen.kit.disko;
        roles.default = {
          inherit (a.roles.default) at;
          settings = pick [ "device" "layout" ] a;
        };
      };
      "${a.name}-facter" = {
        kit = yen.kit.facter;
        roles.default = {
          inherit (a.roles.default) at;
          settings =
            m:
            lib.mapAttrs' (_: v: {
              name = "dir";
              value = v;
            }) (pick [ "hardware" ] a m);
        };
      };
      "${a.name}-sshd" = {
        kit = yen.kit.sshd;
        roles.server.at = a.roles.default.at;
      };
      "${a.name}-emergency" = {
        kit = yen.kit.emergency-access;
        roles.default = {
          inherit (a.roles.default) at;
          settings = pick [ "authorizedKeys" ] a;
        };
      };
    };
  };
}
