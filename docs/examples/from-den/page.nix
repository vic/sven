{
  title = "From Den";
  description = "Den's hosts, users, aspects, includes, defaults and batteries, in yen's four words.";
  section = "migrate";
  order = 3;

  body =
    { docs, ... }:
    [
      ''
        [Den](https://github.com/denful/den) and yen share the aspect idea. The difference is where structure comes from.
        Den gives you a schema: `den.hosts`, users, homes and context pipes. In yen you declare those kinds yourself, in
        plain Nix, and every rule of how content moves is a sink you can read.

        This page moves Den's default template to yen. The docs evaluate both and check that the host gets the same
        account, groups, home, packages and state versions.
      ''
      (docs.table
        [ "Den" "yen" ]
        [
          [
            "`den.hosts.x86_64-linux.igloo.users.tux`"
            "instances: `yen.host.igloo`, `yen.user.tux` with `hosts = [ … ]`"
          ]
          [
            "`den.aspects.igloo.nixos`"
            "an aspect with `at = yen.host.igloo` and a `nixos` key"
          ]
          [
            "`den.default.nixos`"
            "an aspect with `at = yen.kinds.host`"
          ]
          [
            "`includes = [ den.batteries.x ]`"
            "the included aspect's `at` names the includer, from any file"
          ]
          [
            "`provides.to-users.homeManager`"
            "an aspect at the users `within` the host"
          ]
          [
            "`hasAspect`"
            "`yen.lib.holds`, and `result.graph` edges with `origin`"
          ]
          [
            "context pipes, `osConfig`"
            "args: a kind, a sink or `out` (the built flake)"
          ]
          [
            "`den.schema.*`"
            "`yen.kinds.<kind>.fields`"
          ]
        ]
      )
      ''
        ## The template, side by side
      ''
      (docs.tabs [
        {
          label = "Den: den.nix";
          body = docs.file "before/modules/den.nix";
        }
        {
          label = "yen: fleet.nix";
          body = docs.file "modules/fleet.nix";
        }
      ])
      ''
        Den's schema is built in. In yen, `fleet.nix` says the same in one short file: hosts build NixOS, users live under their
        hosts, a user's `homeManager` content goes into the host, and home-manager is active where a user lives.
      ''
      (docs.tabs [
        {
          label = "Den: igloo.nix";
          body = docs.file "before/modules/igloo.nix";
        }
        {
          label = "yen: igloo.nix";
          body = docs.file "modules/igloo.nix";
        }
      ])
      (docs.tabs [
        {
          label = "Den: tux.nix";
          body = docs.file "before/modules/tux.nix";
        }
        {
          label = "yen: tux.nix";
          body = docs.file "modules/tux.nix";
        }
      ])
      ''
        ## Batteries are aspects

        A battery is an aspect that you include. In yen you write the aspect once, without `at`, and each user of it
        adds itself to `at`. `at` from several files is a union.
      ''
      (docs.tabs [
        {
          label = "define-user.nix";
          body = docs.file "modules/batteries/define-user.nix";
        }
        {
          label = "primary-user.nix";
          body = docs.file "modules/batteries/primary-user.nix";
        }
        {
          label = "defaults.nix";
          body = docs.file "modules/defaults.nix";
        }
      ])
      ''
        ## Quirks and pipes are sinks

        In Den, a quirk is structured data that aspects emit on a key registered in `den.quirks`, and pipes are policy effects
        that route it: `pipe.expose` up to the host, `pipe.collect` across hosts, `pipe.filter`, `pipe.as`. By default a quirk stays
        in its own scope. From [Den's docs](https://github.com/denful/den/blob/main/docs/src/content/docs/explanation/quirks-and-pipes.mdx):
      ''
      (docs.nix ''
        den.quirks.firewall = { description = "Firewall port declarations"; };
        den.aspects.nginx = { firewall = { ports = [ 80 443 ]; }; };
        den.aspects.networking.nixos = { firewall, lib, ... }: {
          networking.firewall.allowedTCPPorts = lib.concatMap (f: f.ports or []) firewall;
        };
      '')
      ''
        In yen a quirk is a sink. Where its values land is the tree: an element goes up to the nearest scope that has the sink.
        A user's ports reach its host with no policy, which is Den's `pipe.expose`. `entries` keeps who gave each value, so a
        filter or a rename is a plain function in the reader:
      ''
      (docs.fileWith "{6-13,22}" "modules/quirks.nix")
      (docs.table
        [ "Den" "yen" ]
        [
          [
            "`den.quirks.<q>`"
            "a sink `<q>` on the kind that consumes it"
          ]
          [
            "emit on a quirk key"
            "an aspect key with the sink's name"
          ]
          [
            "consume with `{ firewall, ... }:`"
            "the same: a sink is an arg"
          ]
          [
            "`pipe.expose` (user to host)"
            "routing: the user has no such sink, its host has one"
          ]
          [
            "`pipe.collect`, `pipe.broadcast`"
            "a sink at a common ancestor (the fleet), read by each host"
          ]
          [
            "`pipe.filter`, `pipe.as`"
            "a function over the reduced value, with `entries` for provenance"
          ]
          [
            "a wall: a value that must not leave its scope"
            "a sink with no keys"
          ]
        ]
      )
      ''
        ## Policies are `spawns`

        A Den policy is a function from context to effects, such as `host-to-users` that resolves each user under its host.
        The policy graph (flake, system, host, user, home) is Den's structure. In yen you write that structure as `spawns`:
        `yen.kinds.host.spawns.user` in `fleet.nix` above is Den's `host-to-users`. Conditional policies are a `spawns`
        that reads data or `yen.lib.holds`. Include and exclude effects are `at`, and `not`.
      ''
      (docs.note "Three Den bug families that cannot happen" ''
        - **Double delivery.** An element has one id per receiver.
        - **Lost content when one aspect is in two files.** A read queries all files. Nothing merges early.
        - **A host's home content leaking to its users.** Elements go up the tree, never down.
      '')
      (docs.tip "Every Den capability" ''
        The [reference fleet](https://github.com/vic/yen/tree/main/templates/fleet) shows every capability that Den's CI tests pin
        (168 patterns), and den-hoag's laws, each with a check. See ${
          docs.fleet "modules/den/patterns.nix" null "den/patterns.nix"
        }.
      '')
    ];

  checks =
    { result, ... }:
    {
      quirk-up = result.flake.userPorts == { igloo = [ 3000 ]; };
    };

  e2e =
    {
      inputs,
      dir,
      flake,
      ...
    }:
    let
      sort = builtins.sort builtins.lessThan;
      fp =
        c:
        let
          u = c.users.users.tux;
          h = c.home-manager.users.tux;
        in
        {
          user = {
            inherit (u) isNormalUser home name;
            groups = sort u.extraGroups;
          };
          home = {
            inherit (h.home) username homeDirectory stateVersion;
            packages = sort (map (p: p.name) h.home.packages);
          };
          system = {
            inherit (c.system) stateVersion;
            hello = builtins.any (p: (p.pname or "") == "hello") c.environment.systemPackages;
          };
        };
      den = ((import (dir + "/before/flake.nix")).outputs inputs).nixosConfigurations.igloo.config;
    in
    {
      same-facts = fp den == fp flake.nixosConfigurations.igloo.config;
      ports =
        flake.nixosConfigurations.igloo.config.networking.firewall.allowedTCPPorts == [
          22
          3000
        ];
    };
}
