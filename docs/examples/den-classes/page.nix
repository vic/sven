{
  title = "Custom classes and forward";
  description = "den.batteries.forward and den.classes: a sink whose other keys give its content to a class, at a path.";
  section = "den";
  route = "den/classes";
  order = 4;

  body =
    { docs, ... }:
    [
      ''
        In Den, a custom class is a new aspect key, such as `nix` or `persist`, and `den.batteries.forward` sends its
        content into another class at a path: `fromClass`, `intoClass`, `intoPath`, `adaptArgs`. It is the fifth most
        used battery in public Den configurations.

        In yen a custom class is a sink. Aspects give elements to it by its name. The sink's other keys give the reduced
        content to other sinks, such as `nixos` or `homeManager`, and the function places it at any path. There is no
        `adaptArgs`: the function gets yen args, and the content is plain data.
      ''
      (docs.table
        [ "Den forward" "yen sink" ]
        [
          [
            "`den.classes.nix`"
            "`yen.kinds.<kind>.sinks.nix`"
          ]
          [
            "`fromClass = _: \"nix\"`"
            "the sink name"
          ]
          [
            "`intoClass`, `each = [ \"nixos\" \"homeManager\" ]`"
            "one key per target, on each kind that has the sink"
          ]
          [
            "`intoPath = _: [ \"nix\" \"settings\" ]`"
            "the attribute path in the key's function"
          ]
          [
            "`adaptArgs`"
            "not needed: yen args, such as `host`, are args of the key's function"
          ]
        ]
      )
      ''
        ## One class, two targets

        The same `nix` settings go to `nix.settings` of NixOS on hosts, and of home-manager on standalone homes.
      ''
      (docs.file "modules/nix.nix")
      ''
        ## A class under a path

        This is also the *DRY aspect* of the
        [dendritic design guide](https://github.com/Doc-Steve/dendritic-design-with-flake-parts/wiki/Dendritic_Aspects),
        for options inside an attribute set of submodules. A feature writes `lan` content. The sink puts it under the
        interface that the host names, with `lib.mkMerge`, so two features never overwrite each other.
      ''
      (docs.file "modules/lan.nix")
      (docs.tabs [
        {
          label = "fleet.nix";
          body = docs.file "modules/fleet.nix";
        }
      ])
      (docs.tip "More classes" ''
        The reference fleet has a `git` user sink that forwards into `homeManager`, and a `maid` sink that writes
        dotfiles with no home-manager: ${
          docs.fleet "modules/den/custom-classes.nix" null "den/custom-classes.nix"
        }.
      '')
    ];

  checks =
    { result, ... }:
    {
      outputs =
        builtins.attrNames result.flake.nixosConfigurations == [ "server" ]
        && builtins.attrNames result.flake.homeConfigurations == [ "ana" ];
    };

  e2e =
    { flake, ... }:
    let
      os = flake.nixosConfigurations.server.config;
      hm = flake.homeConfigurations.ana.config;
      lan = os.networking.interfaces.enp86s0;
    in
    {
      nixos =
        builtins.elem "flakes" os.nix.settings.experimental-features && os.nix.settings.max-jobs == 4;
      home =
        builtins.elem "flakes" hm.nix.settings.experimental-features && !(hm.nix.settings ? max-jobs);
      path =
        map (r: r.address) lan.ipv4.routes == [ "192.168.2.0" ]
        && map (a: a.address) lan.ipv4.addresses == [ "10.0.0.1" ];
    };
}
