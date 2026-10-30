{
  title = "Generic batteries";
  description = "mesh, claim, ordered, eval-modules, configurations, imports: values for keys you write. And how to write your own.";
  section = "batteries";
  route = "batteries/generic";
  order = 1;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        The other pages of these docs write every rule by hand, so you can see how yen works. Some rules come back in
        every fleet: each host reads the keys of the other hosts, each address has one owner, sections of a file come
        in an order. `yen.lib.batteries` has them ready.

        A battery never adds a word to your fleet. **You write every key**, with your own names. The battery is the
        value. It reads only the fixed args `scope` and `sinks`, and it takes the sinks it reads as refs.

        | Battery | Value of | Does |
        |---|---|---|
        | `mesh { from; build; }` | any key of an aspect | the records of sink `from`, except the ones that this scope or a scope under it gave; `build` makes content of them |
        | `claim { key; rank ? ; }` | `reduce` of a sink | each key has one owner; two owners is an error, unless `rank` picks one |
        | `ordered` | `reduce` of a sink | elements `{ name; value; before; after; }` in an order that meets all of them |
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## mesh: what the other hosts give

        Each host gives its key to the fleet. The fleet reduces with `entries`, so each key keeps the scope that gave
        it. Each host then reads the keys of the others. This is the same rule as known_hosts, WireGuard peers,
        Syncthing devices or remote builders, written by hand in [Facts from other hosts](/nixos/cross-host/).
      ''
      (docs.file "modules/known-hosts.nix")
      (docs.value result.flake.known)
      ''
        ## claim: one owner per key
      ''
      (docs.file "modules/addresses.nix")
      ''
        When a new host takes the address of the nas, the fleet has an error and no outputs:
      ''
      (docs.value (
        map (e: {
          inherit (e)
            error
            code
            from
            sink
            ;
        }) (variant "variants/clash.nix").errors
      ))
      ''
        With `rank`, the highest value wins and there is no error: for example `rank = claim: claim.priority`, when two
        virtual machines ask for one GPU.

        ## ordered: sections from many files
      ''
      (docs.file "modules/readme.nix")
      (docs.value result.flake.readme)
      ''
        A cycle, a name that is given two times, or an unknown name in `before` or `after` is an error.

        ## Other module systems: eval-modules, configurations, imports

        A sink can collect modules of any module system: NixOS, flake-parts, sini/files, or plain `lib.evalModules`.
        `eval-modules` evaluates them with fixed modules first. `configurations` gives one flake output per scope,
        `<output>.<scope name>`, from a builder you pass (`nixosSystem`, `darwinSystem`, any function). `imports` turns a
        sink of modules into one module for another sink.
      ''
      (docs.file "modules/modules.nix")
      (docs.value {
        inherit (result.flake) settings report;
      })
      ''
        ## Write your own

        A battery is a plain Nix function. If none fits, write one in your fleet. Use the same shape, and it stays as
        reusable as these:

        - Take the sinks you read as refs, such as `from = yen.kinds.fleet.sinks.keys`, and read them with
          `sinks.''${from.__sink}`.
        - Read the scope with `scope`, never with an arg named after a kind.
        - Return a value. Do not write `yen.kinds.…` or `yen.aspects.…` keys: those are the user's names.

        This is all of `mesh`:
      ''
      (docs.nix ''
        mesh =
          { from, build }:
          { scope, sinks, ... }:
          build (map (e: e.value) (builtins.filter (e: !own scope e) sinks.''${from.__sink}));
      '')
    ];

  checks =
    {
      result,
      variant,
      eq,
      yes,
      no,
      ...
    }:
    {
      mesh = eq (result.flake.known) ({
        desk = [
          "ssh-ed25519 AAAAlaptop"
          "ssh-ed25519 AAAAnas"
        ];
        laptop = [
          "ssh-ed25519 AAAAdesk"
          "ssh-ed25519 AAAAnas"
        ];
        nas = [
          "ssh-ed25519 AAAAdesk"
          "ssh-ed25519 AAAAlaptop"
        ];
      });
      claim = eq (result.flake.addrs) ([
        "10.0.0.1"
        "10.0.0.2"
        "10.0.0.3"
      ]);
      clash = {
        t1 = eq (map (e: e.code) (variant "variants/clash.nix").errors) ([ "claim" ]);
        t2 = eq (builtins.attrNames (variant "variants/clash.nix").flake) ([ "invalid-flake-errors" ]);
      };
      ordered = eq (result.flake.readme) ("# My fleet\n## Usage\n## Hosts");
      eval-modules = {
        t1 = eq (result.flake.settings.nas.ssh) ({
          port = 22;
          ciphers = [ "chacha20" ];
        });
        t2 = eq (result.flake.settings.desk.ssh) ({ port = 22; });
      };
      report = eq (builtins.sort builtins.lessThan result.flake.report.hosts) ([
        "desk"
        "laptop"
        "nas"
      ]);
      imports = eq (result.flake.notes.imports) ([ "note" ]);
    };
}
