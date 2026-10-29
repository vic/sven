{
  title = "From a flake";
  description = "Move a flake with a mkHost helper, shared modules and home-manager to yen. Same systems, no helper.";
  section = "migrate";
  order = 2;

  body =
    { docs, ... }:
    [
      ''
        Most flakes grow the same shape: a `mkHost` helper, a `common.nix`, one file per host, and home-manager
        as a NixOS module. This page moves that shape to yen. The docs check that each host gives the same toplevel
        `drvPath` before and after.
      ''
      (docs.tabs [
        {
          label = "flake.nix";
          body = docs.file "before/flake.nix";
        }
        {
          label = "common.nix";
          body = docs.file "before/common.nix";
        }
        {
          label = "hosts/web.nix";
          body = docs.file "before/hosts/web.nix";
        }
        {
          label = "hosts/desk.nix";
          body = docs.file "before/hosts/desk.nix";
        }
        {
          label = "home.nix";
          body = docs.file "before/home.nix";
        }
      ])
      ''
        ## The helper becomes a kind

        `mkHost` knew how to build a host. In yen, the `host` kind knows it: its `nixos` sink builds the system.
        A user's `homeManager` sink forwards to `nixos` on each host the user lives under.
      ''
      (docs.fileWith "{10,16}" "modules/fleet.nix")
      ''
        ## Shared modules become aspects

        `common.nix` was in every host's list. As an aspect it is active at every host. home-manager is active only
        where a user lives:
      ''
      (docs.fileWith "{5,17}" "modules/features/common.nix")
      ''
        ## Host files hold data and hardware

        A host file declares the instance and the parts only that host has. Features that only one host uses are
        aspects with that host in `at`:
      ''
      (docs.tabs [
        {
          label = "hosts/web.nix";
          body = docs.file "modules/hosts/web.nix";
        }
        {
          label = "hosts/desk.nix";
          body = docs.file "modules/hosts/desk.nix";
        }
        {
          label = "features/roles.nix";
          body = docs.file "modules/features/roles.nix";
        }
      ])
      ''
        ## People own their homes

        `home-manager.users.alice` was written in the flake for every host. Now alice is data: she says which hosts
        she uses, and her aspect gives her account and her home:
      ''
      (docs.file "modules/alice.nix")
      (docs.note "Adding a host" ''
        Before: add a line to the flake, and maybe a parameter to `mkHost`. After: add `yen.host.<name>` in its own file,
        and add it to the `hosts` of its users. Nothing else changes.
      '')
      (docs.links [
        {
          title = "Users and homes";
          href = "/recipes/users-homes/";
          description = "home-manager in NixOS, on macs, and standalone.";
        }
        {
          title = "Environments";
          href = "/recipes/environments/";
          description = "prod, staging, lab: hosts grouped by where they run.";
        }
      ])
    ];

  e2e =
    {
      inputs,
      dir,
      flake,
      ...
    }:
    let
      before = ((import (dir + "/before/flake.nix")).outputs inputs).nixosConfigurations;
      t = c: c.config.system.build.toplevel.drvPath;
    in
    {
      same-web = t before.web == t flake.nixosConfigurations.web;
      same-desk = t before.desk == t flake.nixosConfigurations.desk;
    };
}
