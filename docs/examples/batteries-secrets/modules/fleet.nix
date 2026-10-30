# Hosts build NixOS; the repo root writes files. Caches and secrets are sinks any aspect adds to.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  b = yen.lib.batteries;
in
{
  yen.kinds.repo = {
    spawns.host = _: yen.host;
    sinks = {
      out.reduce = yen.lib.reduce.merge;
      files.out = b.files.writer {
        from = yen.kinds.repo.sinks.files;
        inherit (inputs) files;
        inherit lib;
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        root = inputs.self;
      };
    };
  };
  yen.kinds.host.sinks.nixos.out = b.nixos.system {
    from = yen.kinds.host.sinks.nixos;
    inherit (inputs) nixpkgs;
  };
  yen.repo.main = { };
  yen.host.build = { };
  yen.flake = { out, ... }: out;
  yen.aspects.machine = {
    at = yen.kinds.host;
    nixos = {
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
}
