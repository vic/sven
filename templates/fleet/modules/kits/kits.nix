# kits written in yen. A kit is data (roles, typed interface, constraints, the assemblies it adds) plus aspects: an
# aspect at a member scope runs once per assembly and role, an aspect at a machine that `has` a member once per
# machine. borg comes from a file outside modules/, as a kit from another flake.
{ yen, lib, ... }:
let
  inherit (yen.lib) all has same;
  inherit (yen) kit host;
  memberOf =
    k: role: s:
    same (s.kit or null) k && (role == null || s.role == role);
  at =
    k: role:
    all [
      yen.kinds.member
      (memberOf k role)
    ];
  str = lib.types.str;
in
{
  imports = [ (import ../../services/borg.nix) ]; # a value, not a path: it takes the label of this file

  yen.kit = {
    sshd.roles.server = { };
    wifi.roles.default.interface.networks = {
      type = lib.types.attrs;
      default = { };
    };
    users.roles.default.interface.user.type = str;
    banner = {
      roles.default.interface.text = {
        type = str;
        default = "managed by yen";
      };
      constraints.maxAssemblies = 1;
    };
    site = {
      roles.default = { };
      exports = [ "endpoints" ];
    };
  };

  # sshd: one config per machine however many assemblies
  yen.aspects.kit-sshd = {
    at = all [
      yen.helpers.machines
      (has (memberOf kit.sshd null))
    ];
    os.services.openssh.enable = true;
  };
  # wifi: the settings a member reads are interface defaults, then the role's
  yen.aspects.kit-wifi = {
    at = at kit.wifi "default";
    nixos =
      { member, ... }:
      {
        environment.etc."wifi/networks".text = toString (lib.attrNames member.settings.networks);
      };
  };
  # users: many assemblies of one kit on one machine, each its own scope
  yen.aspects.kit-users = {
    at = at kit.users "default";
    nixos =
      { member, ... }:
      {
        users.users.${member.settings.user} = {
          isSystemUser = true;
          group = "nogroup";
        };
      };
  };
  # one assembly gets more: an aspect at its members
  yen.aspects.svc-a-extra = {
    at = all [
      yen.kinds.member
      (s: same (s.assembly or null) yen.assembly.svc-a)
    ];
    os.environment.etc."extra".text = "svc-a";
  };
  # site exports its endpoints; dns, another kit, reads every kit's endpoints
  yen.aspects.kit-site = {
    at = at kit.site "default";
    exports =
      { member, ... }:
      {
        endpoints = [ "${member.assembly.name}.example.org" ];
      };
  };
  yen.aspects.kit-dns = {
    at = yen.kinds.fleet;
    out =
      { exports, ... }:
      {
        cnames = lib.concatMap (
          x:
          map (e: {
            name = e;
            target = x.machine.name;
          }) (x.value.endpoints or [ ])
        ) exports;
      };
  };
  yen.aspects.kit-banner = {
    at = at kit.banner "default";
    os =
      { member, ... }:
      {
        environment.etc."banner".text = member.settings.text;
      };
  };

  # assemblies: each role's machines are a predicate of refs, kinds and aspects
  yen.assembly = {
    backup = {
      kit = kit.borg;
      roles = {
        client = {
          at = yen.kinds.host;
          settings.startAt = "02:00";
        };
        server.at = host.lb;
      };
    };
    wifi = {
      kit = kit.wifi;
      roles.default = {
        at = yen.aspects.role-laptop;
        settings.networks = {
          home = { };
          office = { };
        };
      };
    };
    svc-a = {
      kit = kit.users;
      roles.default = {
        at = host.lb;
        settings.user = "svc-a";
      };
    };
    svc-b = {
      kit = kit.users;
      roles.default = {
        at = host.lb;
        settings.user = "svc-b";
      };
    };
    banner = {
      kit = kit.banner;
      roles.default.at = yen.kinds.mac;
    };
    docs = {
      kit = kit.site;
      roles.default.at = host.web-1;
    };
    sshd = {
      kit = kit.sshd;
      roles.server.at = yen.helpers.machines;
    };
  };
}
