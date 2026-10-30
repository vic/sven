# The kits come from the library; the fleet writes only assemblies: which machines take which role.
{ yen, inputs, ... }:
let
  inherit (yen) host kit;
  lib' = inputs.yen.lib.kits;
in
{
  imports = [
    lib'.borg
    lib'.wifi
    lib'.remote-builders
    (lib'.nix-cache { root = ../vars/per-machine; })
    lib'.monitoring
    lib'.postgres
  ];
  yen.kit.sshd.roles.server = { }; # borg adds an assembly of it
  yen.host = {
    lb.addr = "10.0.0.1";
    web.addr = "10.0.0.2";
    nas.addr = "10.0.0.3";
  };
  yen.assembly = {
    backup = {
      kit = kit.borg;
      roles = {
        client = {
          at = host.web;
          settings.startAt = "02:00";
        };
        server.at = host.nas;
      };
    };
    wifi = {
      kit = kit.wifi;
      roles.default = {
        at = host.web;
        settings.networks = {
          home = { };
          office = { };
        };
      };
    };
    builders = {
      kit = kit.remote-builders;
      roles = {
        builder = {
          at = host.nas;
          settings.speedFactor = 4;
        };
        client.at = host.web;
      };
    };
    cache = {
      kit = kit.nix-cache;
      roles = {
        server = {
          at = host.nas;
        };
        client.at = [
          host.web
          host.lb
        ];
      };
    };
    metrics = {
      kit = kit.monitoring;
      roles = {
        server.at = host.lb;
        exporter.at = [
          host.web
          host.nas
        ];
      };
    };
    db = {
      kit = kit.postgres;
      roles = {
        server.at = host.nas;
        client = {
          at = host.web;
          settings = {
            database = "shop";
            user = "shop";
          };
        };
      };
    };
  };
}
