{
  title = "Shared pkgs";
  description = "Import nixpkgs once per system, not once per host. Same systems, about a third less evaluation.";
  section = "perf";
  order = 1;

  body =
    { docs, ... }:
    [
      ''
        yen's own part of a host's evaluation is small: 1.4% on the reference fleet's `lb`. Most of the time goes to
        nixpkgs `pkgs` (56%) and the NixOS module system (36%). By default every host imports nixpkgs again.

        With `sharedPkgs = true`, a host reuses the `pkgs` of the first sharing host on its system (the leader),
        through nixpkgs' `readOnlyPkgs` module. The `out` arg gives the leader's built `pkgs`, lazily.
      ''
      (docs.fileWith "{32,34,36}" "modules/fleet.nix")
      (docs.file "modules/hosts.nix")
      ''
        ## The oracle

        A follower must build exactly what it builds alone. `ownPkgs` is each host built with its own `pkgs`.
        The docs check that every host's toplevel `drvPath` is the same both ways.
      ''
      (docs.table
        [ "Reference fleet: lb, web-1, web-2 toplevel" "CPU" "Thunks" "GC total" ]
        [
          [
            "each its own pkgs"
            "35.3 s"
            "36.6 M"
            "2.71 GB"
          ]
          [
            "shared pkgs"
            "24.8 s"
            "29.3 M"
            "1.96 GB"
          ]
        ]
      )
      ''
        Measured on the reference fleet, with the same `drvPath`s both ways
        ([README](https://github.com/vic/yen/tree/main/templates/fleet#shared-pkgs-one-nixpkgs-per-channel-and-system)).
      ''
      (docs.caution "Two rules" ''
        - A sharing host cannot set `nixpkgs.config` or `nixpkgs.overlays` of its own: the group shares them.
          Give the same ones to every host in the group, or leave the host out of the group.
        - Keep documentation off on sharing hosts. The manual and man pages differ when `pkgs` is shared.
      '')
    ];

  # fast: the group and its leader, with no NixOS eval (the e2e checks below build the systems)
  checks =
    { result, eq, ... }:
    {
      leader = eq result.flake.sharedLeader {
        app-1 = null;
        app-2 = "app-1";
        app-3 = "app-1";
      };
    };

  e2e =
    { flake, eq, ... }:
    let
      t = c: c.config.system.build.toplevel.drvPath;
    in
    builtins.listToAttrs (
      map
        (h: {
          name = "same-${h}";
          value = eq (t flake.nixosConfigurations.${h}) (t flake.ownPkgs.${h});
        })
        [
          "app-1"
          "app-2"
          "app-3"
        ]
    );
}
