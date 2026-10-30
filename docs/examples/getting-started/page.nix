{
  title = "Getting started";
  description = "One NixOS host, from an empty directory, in four files.";
  section = "start";
  order = 2;

  body =
    { docs, result, ... }:
    [
      ''
        This page builds one NixOS host with yen. You write four small files. At the end you have a
        `nixosConfigurations.laptop` that `nixos-rebuild` can use.
      ''
      (docs.steps [
        ''
          Get the template. It has a `flake.nix` and a `modules/` directory.

          ${docs.sh "nix flake init -t github:vic/yen#getting-started"}
        ''
        ''
          Read `flake.nix`. The `yen` input is a normal flake input.
          [import-tree](https://github.com/denful/import-tree) loads every file in `modules/`.

          ${docs.file "flake.nix"}
        ''
        ''
          Build the host:

          ${docs.sh "nix build .#nixosConfigurations.laptop.config.system.build.toplevel"}
        ''
      ])
      ''
        ## The fleet

        yen has no built-in kinds. You say what a fleet is. The root kind is the one that nothing spawns.
        Here the root `fleet` spawns every host, and its `out` sink is the flake.
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## The host

        A kind has `fields` (the data of each instance) and `sinks` (where behavior goes).
        The `nixos` sink collects NixOS modules. Its `out` key gives the built system to the flake.
      ''
      (docs.fileWith "{13}" "modules/host.nix")
      ''
        ## Behavior

        An aspect is active where its `at` holds. Each key of an aspect gives one element to the sink
        of that name. `base` is active at every host. `motd` is active at `laptop` only.
      ''
      (docs.file "modules/aspects.nix")
      (docs.note "Args are filled for you" ''
        `{ host, ... }:` asks yen for the nearest host. yen fills it, and the rest of the function stays a normal NixOS module.
      '')
      ''
        ## Ask it

        yen answers queries on the fleet. This is the scope tree of this example, generated from `result.graph`:
      ''
      (docs.scopes result)
      ''
        And `result.active`: which aspect is active at which scope.
      ''
      (docs.value result.active)
      (docs.links [
        {
          title = "Project layout";
          href = "/start/project-layout/";
          description = "Flakes, no flakes, and where files go.";
        }
        {
          title = "Kinds and fields";
          href = "/concepts/kinds-fields/";
          description = "Typed data, the first of yen's four words.";
        }
      ])
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      scopes = eq (map (s: s.id) result.graph.scopes) ([
        "fleet:main"
        "fleet:main/host:laptop"
      ]);
      motd-at-laptop = yes (result.active.motd."fleet:main/host:laptop");
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    {
      hostname = eq (flake.nixosConfigurations.laptop.config.networking.hostName) ("laptop");
      motd = eq (flake.nixosConfigurations.laptop.config.environment.etc.motd.text) ("managed by yen");
    };
}
