# install and deploy: the library kit disko gives a machine its disk layout; each machine with one gets an app
# `install-<machine>` (nixos-anywhere), and each machine with a deploy target an app `rebuild-<machine>`.
# The fleet has no disko input: `options.disko.devices` stands in for the disko NixOS module.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  b = yen.lib.batteries;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux; # the operator's system (apps run where the flake runs), not the target host's `system`
in
{
  imports = [ inputs.yen.lib.kits.disko ];

  yen.kinds.host.sinks = {
    disks = {
      reduce = yen.lib.reduce.merge;
      out = b.install.apps {
        from = yen.kinds.host.sinks.disks;
        inherit pkgs;
        report = h: "./hardware/${h.name}.json";
        target = h: "root@${h.addr}";
      };
    };
    deploy.out = b.deploy.rebuild {
      from = yen.kinds.host.sinks.deploy;
      inherit pkgs;
    };
  };

  yen.aspects.disko-devices = {
    at = yen.kinds.host;
    nixos = b.disko { from = yen.kinds.host.sinks.disks; };
  };
  yen.aspects.disko-option = {
    at = yen.kinds.host;
    nixos.options.disko.devices = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };

  yen.assembly = {
    disk-stage = {
      kit = yen.kit.disko;
      roles.default = {
        at = yen.host.stage;
        settings = {
          device = "/dev/sda";
          layout = yen.layout.single-ext4;
        };
      };
    };
    disk-web-1 = {
      kit = yen.kit.disko;
      roles.default = {
        at = yen.host.web-1;
        settings = {
          device = "/dev/nvme0n1";
          layout = yen.layout.btrfs-luks;
        };
      };
    };
    disk-web-2 = {
      kit = yen.kit.disko;
      roles.default = {
        at = yen.host.web-2;
        settings = {
          device = "/dev/sda /dev/sdb";
          layout = yen.layout.zfs-mirror;
        };
      };
    };
  };
}
