{
  title = "Many hosts, one base";
  description = "Replace the mkHost function, readDir ./hosts and specialArgs.hostname with host instances and aspects.";
  section = "nixos";
  route = "nixos/hosts";
  order = 1;

  body =
    { docs, variant, ... }:
    [
      ''
        Most flakes with more than one machine grow a `mkHost` function. It takes a host name, imports a shared module
        and `./hosts/''${name}`, sets `networking.hostName`, and passes values in `specialArgs`. When there are many hosts,
        a `vars.nix` file merges defaults, then category values, then host values. Tools such as
        [easy-hosts](https://github.com/tgirlcloud/easy-hosts) add modules per class, per arch and per tag.
      ''
      (docs.nix ''
        # flake.nix: the usual shape
        nixosConfigurations = lib.genAttrs (builtins.attrNames (builtins.readDir ./hosts)) (
          name:
          nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; hostname = name; vars = getHostVars name; };
            modules = [ ./common.nix ./hosts/''${name} { networking.hostName = name; } ];
          }
        );
      '')
      ''
        In yen a host is an instance of a kind. The kind builds the NixOS system once. Shared configuration is an aspect
        at the kind. Host values are typed fields with defaults, and every NixOS module of an aspect can read them as
        the `host` arg.
      ''
      (docs.table
        [ "Usual pattern" "yen" ]
        [
          [
            "`mkHost \"tower\"`"
            "`yen.host.tower = { }`"
          ]
          [
            "`builtins.readDir ./hosts`"
            "import-tree: each file under `modules/hosts/` declares its host"
          ]
          [
            "`specialArgs.hostname`, `specialArgs.vars`"
            "`{ host, ... }:` in the NixOS module of any aspect"
          ]
          [
            "`vars.nix`: defaults, category, host"
            "`fields` with defaults; for layered values see [Environments](/recipes/environments/)"
          ]
          [
            "easy-hosts `perArch`, `perClass`, `perTag`"
            "an aspect whose `at` reads a field; see [Roles from data](/recipes/roles/)"
          ]
          [
            "`nixos-rebuild switch --flake .#tower`"
            "the same: the output name is the instance name"
          ]
        ]
      )
      ''
        ## The kind
      ''
      (docs.file "modules/fleet.nix")
      ''
        A wrong value fails at the instance that sets it, not deep in `nixpkgs.hostPlatform`. With
        `yen.host.tower.system = "x86-64-linux"`, the result has this error, as data:
      ''
      (docs.value (map (e: removeAttrs e [ "value" ]) (variant "variants/typo.nix").errors))
      ''
        ## The base, per arch, per form
      ''
      (docs.file "modules/base.nix")
      ''
        ## One file per host
      ''
      (docs.tabs [
        {
          label = "tower.nix";
          body = docs.file "modules/hosts/tower.nix";
        }
        {
          label = "thinkpad.nix";
          body = docs.file "modules/hosts/thinkpad.nix";
        }
        {
          label = "pi.nix";
          body = docs.file "modules/hosts/pi.nix";
        }
      ])
      ''
        A real host file usually imports its `hardware-configuration.nix` in its `nixos` key, next to the instance.
      ''
      (docs.note "What you stop writing" ''
        - The `mkHost` function, and the list of shared modules that every host repeats.
        - `specialArgs` and `extraSpecialArgs`: the `host` arg is in every module of an aspect, and in home-manager too.
        - `lib.mkIf (hostname == "pi")` in shared modules: the aspect's `at` says where it applies.
      '')
      (docs.tip "As a battery" ''
        The kind that builds NixOS and the hostname rule are ready as `yen.lib.batteries.nixos.system` and
        `hostname`: see [NixOS batteries](/batteries/nixos/). This page writes them by hand, so you can change them.
      '')
    ];

  checks =
    { result, variant, ... }:
    {
      typo =
        map (e: e.from + " " + builtins.toJSON e.path) (variant "variants/typo.nix").errors
        == [ "host:tower [\"system\"]" ];
      hosts =
        builtins.attrNames result.flake.nixosConfigurations == [
          "pi"
          "thinkpad"
          "tower"
        ];
    };

  e2e =
    { flake, ... }:
    let
      c = n: flake.nixosConfigurations.${n}.config;
    in
    {
      names =
        map (n: (c n).networking.hostName) [
          "pi"
          "tower"
        ] == [
          "pi"
          "tower"
        ];
      arm = (c "pi").nixpkgs.hostPlatform.system == "aarch64-linux";
      arm-only =
        (c "pi").boot.loader.generic-extlinux-compatible.enable
        && !(c "tower").boot.loader.generic-extlinux-compatible.enable;
      laptop-only = (c "thinkpad").services.upower.enable && !(c "tower").services.upower.enable;
    };
}
