# clan services written in yen. A service is data (roles, typed interface, constraints, nested instances) plus
# aspects: an aspect at a member scope is clan's perInstance, an aspect at a machine that `has` a member is perMachine.
# borg comes from another file through a function, as clan's `module.input` loads a service from another flake.
{ yen, lib, ... }:
let
  inherit (yen.lib) all has;
  memberOf =
    svc: role: s:
    s.service or null == svc && (role == null || s.role == role);
  at =
    svc: role:
    all [
      yen.kinds.member
      (memberOf svc role)
    ];
  str = lib.types.str;
in
{
  imports = [ (import ../../services/borg.nix { prefix = "fleet"; }) ];

  yen.helpers.clan.services = {
    sshd.roles.server = { };
    wifi.roles.default.interface.networks = {
      type = lib.types.attrs;
      default = { };
    };
    users = {
      roles.default.interface.user = {
        type = str;
      };
    };
    banner = {
      roles.default.interface.text = {
        type = str;
        default = "managed by yen";
      };
      constraints.maxInstances = 1;
    };
    site = {
      roles.default = { };
      exports = [ "endpoints" ];
    };
  };

  # sshd: one config per machine however many instances (perMachine)
  yen.aspects.clan-sshd = {
    at = all [
      yen.helpers.machines
      (has (memberOf "sshd" null))
    ];
    os.services.openssh.enable = true;
  };
  # wifi: the settings a member reads are interface defaults, then role-wide, then this machine's
  yen.aspects.clan-wifi = {
    at = at "wifi" "default";
    nixos =
      { member, ... }:
      {
        environment.etc."wifi/networks".text = toString (lib.attrNames member.settings.networks);
      };
  };
  # users: many instances of one service on one machine, each its own scope
  yen.aspects.clan-users = {
    at = at "users" "default";
    nixos =
      { member, ... }:
      {
        users.users.${member.settings.user} = {
          isSystemUser = true;
          group = "nogroup";
        };
      };
  };
  # site exports its endpoints; dns, another service, reads every service's endpoints (clan dm-dns)
  yen.aspects.clan-site = {
    at = at "site" "default";
    exports =
      { member, ... }:
      {
        endpoints = [ "${member.instance}.example.org" ];
      };
  };
  yen.aspects.clan-dns = {
    at = yen.kinds.fleet;
    out =
      { exports, ... }:
      {
        cnames = lib.concatMap (
          x:
          map (e: {
            name = e;
            target = x.machine;
          }) (x.value.endpoints or [ ])
        ) exports;
      };
  };
  yen.aspects.clan-banner = {
    at = at "banner" "default";
    os =
      { member, ... }:
      {
        environment.etc."banner".text = member.settings.text;
      };
  };

  # instances (clan inventory.instances); labels are clan tags
  yen.host.stage.labels = [ "laptop" ];
  yen.instance = {
    backup = {
      module = "borg";
      roles = {
        client = {
          tags = [ "nixos" ];
          settings.startAt = "02:00";
        };
        server.machines.lb = { };
      };
    };
    wifi.roles.default = {
      tags = [ "laptop" ];
      settings.networks.home = { };
      machines.stage.settings.networks.office = { };
    };
    svc-a = {
      module = "users";
      roles.default = {
        machines.lb = { };
        settings.user = "svc-a";
        extraModules = [ { environment.etc."extra".text = "svc-a"; } ];
      };
    };
    svc-b = {
      module = "users";
      roles.default = {
        machines.lb = { };
        settings.user = "svc-b";
      };
    };
    banner.roles.default.tags = [ "darwin" ];
    docs = {
      module = "site";
      roles.default.machines.web-1 = { };
    };
    sshd.roles.server.tags = [ "all" ];
  };
}
