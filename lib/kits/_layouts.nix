# the layouts of kit disko: each `devices` makes disko devices from the device string the member sets
{ lib }:
let
  b = builtins;
  esp = {
    size = "512M";
    type = "EF00";
    content = {
      type = "filesystem";
      format = "vfat";
      mountpoint = "/boot";
    };
  };
  disk = device: partitions: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      inherit partitions;
    };
  };
  # a mirror names two devices, separated by a space
  pair = d: b.filter (x: b.isString x && x != "") (b.split " +" d);
in
{
  single-ext4.devices = device: {
    disk.main = disk device {
      ESP = esp;
      root = {
        size = "100%";
        content = {
          type = "filesystem";
          format = "ext4";
          mountpoint = "/";
        };
      };
    };
  };
  btrfs-luks.devices = device: {
    disk.main = disk device {
      ESP = esp;
      luks = {
        size = "100%";
        content = {
          type = "luks";
          name = "crypted";
          content = {
            type = "btrfs";
            subvolumes = {
              "@root".mountpoint = "/";
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
  zfs-mirror.devices = d: {
    disk = b.listToAttrs (
      lib.imap0 (i: device: {
        name = "d${toString i}";
        value = disk device {
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "tank";
            };
          };
        };
      }) (pair d)
    );
    zpool.tank = {
      type = "zpool";
      mode = "mirror";
      datasets."root" = {
        type = "zfs_fs";
        mountpoint = "/";
      };
    };
  };
}
