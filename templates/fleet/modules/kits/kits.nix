# kits written in yen. A kit is data (roles, typed interface, constraints, the assemblies it adds) plus aspects: an
# aspect at a member scope runs once per assembly and role, an aspect at a machine that `has` a member once per
# machine. borg, wifi, sshd, users and dns come from yen.lib.kits.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib) all same;
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
  imports = [
    inputs.yen.lib.kits.borg
    inputs.yen.lib.kits.wifi
    inputs.yen.lib.kits.dns
    inputs.yen.lib.kits.sshd
    inputs.yen.lib.kits.users
  ]; # kits of the library

  yen.kit = {
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

  # one assembly gets more: an aspect at its members
  yen.aspects.svc-a-extra = {
    at = all [
      yen.kinds.member
      (s: same (s.assembly or null) yen.assembly.svc-a)
    ];
    os.environment.etc."extra".text = "svc-a";
  };
  # site exports its endpoints; dns (inputs.yen.lib.kits.dns), another kit, reads every kit's endpoints
  yen.aspects.kit-site = {
    at = at kit.site "default";
    exports =
      { member, ... }:
      {
        endpoints = [ "${member.assembly.name}.example.org" ];
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
