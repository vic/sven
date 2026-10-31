# Assemblies of the library kits. `layout` is a ref to a layout, never a string; `dir` holds one facter report per machine.
{ yen, lib, ... }:
{
  yen.kinds.member = { };
  yen.kinds.kit.fields = {
    roles = yen.lib.opt (yen.lib.is lib.isAttrs) { };
    constraints = yen.lib.opt (yen.lib.is lib.isAttrs) { };
  };
  yen.kinds.assembly.fields = {
    kit = yen.kinds.kit;
    roles = yen.lib.opt (yen.lib.is lib.isAttrs) { };
  };
  yen.aspects.settings-typed = {
    at = yen.kinds.member;
    errors = yen.lib.batteries.kits.settings-typed;
  };

  yen.assembly = {
    disk-lb = {
      kit = yen.kit.disko;
      roles.default = {
        at = yen.host.lb;
        settings = {
          device = "/dev/sda";
          layout = yen.layout.single-ext4;
        };
      };
    };
    disk-web = {
      kit = yen.kit.disko;
      roles.default = {
        at = yen.host.web;
        settings = {
          device = "/dev/nvme0n1";
          layout = yen.layout.btrfs-luks;
        };
      };
    };
    disk-nas = {
      kit = yen.kit.disko;
      roles.default = {
        at = yen.host.nas;
        settings = {
          device = "/dev/sda /dev/sdb";
          layout = yen.layout.zfs-mirror;
        };
      };
    };
    hardware = {
      kit = yen.kit.facter;
      roles.default = {
        at = yen.host.lb;
        settings.dir = ../hardware;
      };
    };
  };
}
