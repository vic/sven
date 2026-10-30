# Four kinds of machine and standalone homes. Each kind's sink builds its output with a battery.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  b = yen.lib.batteries;
  pkgsOf = s: inputs.nixpkgs.legacyPackages.${s.system};
  machine = {
    spawns.user = s: lib.filterAttrs (_: u: lib.any (yen.lib.same s) u.on) yen.user;
  };
in
{
  yen.kinds.fleet = {
    spawns = {
      host = _: yen.host;
      mac = _: yen.mac;
      phone = _: yen.phone;
      home = _: yen.home;
    };
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host = machine // {
    fields.system = lib.types.str;
    spawns = machine.spawns // {
      guest = s: lib.filterAttrs (_: g: yen.lib.same g.on s) yen.guest;
    };
    sinks.nixos.out = b.nixos.system {
      from = yen.kinds.host.sinks.nixos;
      inherit (inputs) nixpkgs;
    };
    sinks.os.nixos = b.imports { from = yen.kinds.host.sinks.os; }; # a user's home (os) into NixOS
  };
  yen.kinds.guest = {
    fields = {
      on = yen.kinds.host;
      system = lib.types.str;
    };
    # a guest's NixOS goes into its host as microvm.vms.<guest>
    sinks.nixos.nixos = b.microvm.guest {
      from = yen.kinds.guest.sinks.nixos;
      pkgs = pkgsOf;
    };
  };
  yen.kinds.mac = machine // {
    fields.system = lib.types.str;
    sinks.darwin.out = b.darwin.system {
      from = yen.kinds.mac.sinks.darwin;
      darwinSystem = _: inputs.nix-darwin.lib.darwinSystem;
      system = m: m.system;
    };
    sinks.os.darwin = b.imports { from = yen.kinds.mac.sinks.os; };
  };
  yen.kinds.phone = {
    fields.system = lib.types.str;
    sinks.droid.out = b.droid.system {
      from = yen.kinds.phone.sinks.droid;
      inherit (inputs.nix-on-droid.lib) nixOnDroidConfiguration;
      # nix-on-droid pins its own nixpkgs: newer nixpkgs dropped lib.mdDoc, which it still uses
      pkgs = s: import inputs.nix-on-droid.inputs.nixpkgs { inherit (s) system; };
    };
    sinks.homeManager.droid = b.droid.home { from = yen.kinds.phone.sinks.homeManager; };
  };
  yen.kinds.home = {
    fields = {
      user = yen.kinds.user;
      system = lib.types.str;
    };
    sinks.homeManager.out = b.home-manager.system {
      from = yen.kinds.home.sinks.homeManager;
      homeManagerConfiguration = _: inputs.home-manager.lib.homeManagerConfiguration;
      pkgs = pkgsOf;
    };
  };
  yen.kinds.user = {
    fields.on = yen.lib.is lib.isList;
    # a user's home goes into the machine it is on
    sinks.homeManager.os = b.home-manager.into-host { from = yen.kinds.user.sinks.homeManager; };
  };
  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
