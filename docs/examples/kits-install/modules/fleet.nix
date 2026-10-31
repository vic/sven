# Machines, the sinks that install and deploy read, and the kits of the install lane.
# The kits are modules: in your flake they go in `imports` of the top module (`inputs.yen.lib.kits.disko`).
{
  yen,
  lib,
  inputs,
  ...
}:
let
  b = yen.lib.batteries;
  inherit (yen.lib) maybe;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in
{
  imports = [
    (import ../../../../lib/kits/disko.nix)
    (import ../../../../lib/kits/facter.nix)
  ];

  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = {
    fields = {
      addr = lib.types.str;
      buildHost = maybe lib.types.str;
    };
    spawns.member = yen.lib.batteries.kits.members {
      assemblies = lib.attrValues yen.assembly;
      inherit (yen.lib) holds;
    };
    sinks = {
      # what the machine's own modules say; the facter and disko batteries write here
      nixos = {
        reduce = yen.lib.reduce.merge;
        out =
          { scope, sinks, ... }:
          {
            config.${scope.name} = sinks.nixos;
          };
      };
      # the disk layout: disko reads it; install makes the app `install-<machine>` of it
      disks = {
        reduce = yen.lib.reduce.merge;
        out = b.install.apps {
          from = yen.kinds.host.sinks.disks;
          inherit pkgs;
          report = h: "./hardware/${h.name}.json";
          target = h: "root@${h.addr}";
        };
      };
      # the deploy target (one per machine); rebuild makes the app `rebuild-<machine>` of it
      deploy = {
        reduce = yen.lib.reduce.one;
        out = b.deploy.rebuild {
          from = yen.kinds.host.sinks.deploy;
          inherit pkgs;
        };
      };
    };
  };

  yen.fleet.main = { };
  yen.host = {
    lb = {
      addr = "10.0.0.1";
    };
    web = {
      addr = "10.0.0.2";
      buildHost = "10.0.0.1";
    };
    nas.addr = "10.0.0.3";
  };
  yen.flake = { out, ... }: out;

  yen.aspects = {
    nixos-disko = {
      at = yen.kinds.host;
      nixos = b.disko { from = yen.kinds.host.sinks.disks; };
    };
    deploy-target = {
      at = yen.host.web;
      deploy =
        { host, ... }:
        {
          inherit (host) buildHost;
          address = host.addr;
          user = "deploy";
        };
    };
  };
}
