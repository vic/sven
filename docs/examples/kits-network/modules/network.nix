# Network kits shipped with yen: write only assemblies. `root` is where public keys and ids are read from.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen) kit machine;
  inherit (yen.lib) same;
  root = ../vars/per-machine;
in
{
  imports = [
    (inputs.yen.lib.kits.wireguard { inherit root; })
    (inputs.yen.lib.kits.zerotier { inherit root; })
    inputs.yen.lib.kits.dns
  ];
  yen.machine = {
    lb.addr = "10.0.1.1";
    web.addr = "10.0.1.10";
    db.addr = "10.0.1.20";
  };

  # wireguard: lb is the hub, web and db are peers; addresses come from the prefix, in member order
  yen.assembly.vpn = {
    kit = kit.wireguard;
    roles = {
      controller = {
        at = machine.lb;
        settings.prefix = "10.8.0.0/24";
      };
      peer = {
        at = m: same m machine.web || same m machine.db;
        settings = {
          prefix = "10.8.0.0/24";
          port = 51821;
        };
      };
    };
  };
  # zerotier: one controller, up to four moons, any machine as a peer
  yen.assembly.lan = {
    kit = kit.zerotier;
    roles = {
      controller.at = machine.lb;
      moon.at = machine.web;
      peer.at = machine.db;
    };
  };

  # a kit that gives endpoints; dns reads them
  yen.kit.site = {
    roles.default = { };
    exports = [ "endpoints" ];
  };
  yen.assembly.site = {
    kit = kit.site;
    roles.default.at = machine.web;
  };
  yen.aspects.site = {
    at = yen.lib.all [
      yen.kinds.member
      (s: same (s.kit or null) kit.site)
    ];
    exports = {
      endpoints = [ "www.example.org" ];
    };
  };
}
