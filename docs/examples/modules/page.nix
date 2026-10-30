{
  title = "Yen modules are not NixOS modules";
  description = "A yen module has `imports`, `_module.args` and `yen`. yen does not use nixpkgs. Each NixOS pattern, and how to write it in yen.";
  section = "principles";
  order = 4;

  body =
    {
      docs,
      result,
      variant,
      inputs,
      ...
    }:
    let
      t = inputs.nixpkgs.lib.types;
    in
    [
      ''
        A yen module looks like a NixOS module: a path, a function or an attrset, with `imports`. It is not one.
        yen does not use the NixOS module system and does not depend on nixpkgs: it uses Nix builtins only.
        A yen module has three keys:

        - `imports`: more yen modules.
        - `_module.args`: args for the modules below, such as `lib` or `inputs`.
        - `yen`: every declaration.

        There is no `options`, no `config` and no free-form key. A key that yen does not read is an error,
        at the top of a module, inside `yen` and inside a kind:
      ''
      (docs.file "variants/nixos-style.nix")
      (docs.value (map (e: { inherit (e) code error path; }) (variant "variants/nixos-style.nix").errors))
      ''
        ## Types: anything with `check`

        A field type is any value with `check = v: bool`. yen does not ship its own type library, and it needs no
        nixpkgs. Use what you have:

        - `yen.lib.is f`: any predicate, for example `yen.lib.is builtins.isString`.
        - nixpkgs types, if you have `lib`: `lib.types.str`, `lib.types.port`. Read the warning below.
        - [nix-effects](https://github.com/kleisli-io/nix-effects) types: `Int`, `ListOf`, `Record`, refinements.
        - [gen-types](https://github.com/sini/gen) checkers, through their `verify`.

        yen keeps validation apart from merging. A type only checks a value. How many values become one is the
        sink's `reduce`, its merge strategy: see [Sinks](/behavior/sinks/). A nixpkgs type does both, in `check` and
        `merge`. yen calls only `check`.
      ''
      (docs.caution "nixpkgs composite types do not check their items" ''
        In nixpkgs, `listOf`, `attrsOf`, `submodule` and `functionTo` check only the outer shape. The items are
        checked in `merge`, which yen never calls. So in yen, `lib.types.listOf lib.types.int` accepts a list of
        strings:

        ${docs.nix ''
          (lib.types.listOf lib.types.int).check [ "a" ]          # ${
            builtins.toJSON ((t.listOf t.int).check [ "a" ])
          }
          (lib.types.attrsOf lib.types.int).check { x = "a"; }    # ${
            builtins.toJSON ((t.attrsOf t.int).check { x = "a"; })
          }
          (lib.types.submodule { options = { }; }).check { y = 1; } # ${
            builtins.toJSON ((t.submodule { options = { }; }).check { y = 1; })
          }
          (lib.types.functionTo lib.types.int).check (x: "a")     # ${
            builtins.toJSON ((t.functionTo t.int).check (x: "a"))
          }
        ''}
        Use nixpkgs leaf types (`str`, `int`, `bool`, `port`, `enum`, `nullOr`) freely. For a list or an attrset
        whose items matter, use nested fields with a leaf type at each leaf, or a type that checks deep.
      '')
      ''
        nix-effects types check deep, and the kernel can build a check for you: `verified.verify` type-checks an
        implementation against its specification and gives a plain Nix function. That function is a check:
      ''
      (docs.nix ''
        let
          inherit (fx.types) ListOf Int Record hoas verified;
          H = hoas;
          v = verified;
          # String -> [String] -> Bool, verified by the kernel, extracted as a plain Nix function
          strElem = v.verify (H.forall "t" H.string (_: H.forall "xs" (H.listOf H.string) (_: H.bool))) (
            v.fn "t" H.string (t: v.fn "xs" (H.listOf H.string) (xs: v.strElem t xs))
          );
        in
        {
          yen.kinds.host.fields = {
            ports = ListOf Int; # [ "a" ] fails `check`
            owner = Record { name = fx.types.String; };
            target = yen.lib.is (t: strElem t [ "module" "file" "package" ]); # "fleet" fails `check`
          };
        }
      '')
      ''
        A gen-types checker has `verify`, which gives `null` or the reason a value fails. Its `check` follows the
        nixpkgs protocol and is not `v: bool`, so give yen a check made from `verify`:
      ''
      (docs.nix ''
        yen.kinds.host.fields.ports = yen.lib.is (v: (gen.listOf gen.int).verify v == null);
      '')
      ''
        ## Each NixOS pattern, in yen

        The kinds hold what NixOS `options` hold. The instances hold what `config` holds:
      ''
      (docs.file "modules/kinds.nix")
      (docs.file "modules/fleet.nix")
      (docs.table
        [ "NixOS" "yen" ]
        [
          [
            "`options.x = mkOption { type; default; }`"
            "`yen.kinds.K.fields.x = yen.lib.opt type default`"
          ]
          [
            "`mkEnableOption`"
            "a nested field: `fields.firewall.enable = yen.lib.opt lib.types.bool false`"
          ]
          [
            "`default = f config`"
            "`yen.lib.derive type f`: see [Types](/model/types/)"
          ]
          [
            "`config.x = v`"
            "instance data: `yen.host.web.x = v`"
          ]
          [
            "`mkIf config.firewall.enable`"
            "`at = yen.lib.all [ yen.kinds.host (s: s.firewall.enable) ]`"
          ]
          [
            "list and attrset options from many modules"
            "a sink with a `reduce`: see [Sinks](/behavior/sinks/)"
          ]
          [
            "`mkDefault`, `mkForce`"
            "a type default, then the instance value. Two values for one leaf are `two-answers`"
          ]
          [
            "`assertions`"
            "`yen.invariants`, or an aspect's `errors` key"
          ]
          [
            "`imports`, `specialArgs`"
            "`imports`, `_module.args`"
          ]
          [
            "`attrsOf (submodule { … })`"
            "a kind with instances, below"
          ]
        ]
      )
      (docs.value result.reduced.nixos)
      (docs.note "Guard `at` with the kind" ''
        `at` runs at every scope. `s: s.firewall.enable` alone fails at the fleet scope, which has no `firewall`.
        `yen.lib.all [ yen.kinds.host … ]` reads the field only on hosts.
      '')
      ''
        ## Submodules

        In NixOS, `users.users.<name>` and `services.nginx.virtualHosts.<name>` are `attrsOf (submodule { … })`:
        a module inside each value, with its own options. `submoduleWith` adds args and more modules to each one.
        Each value is merged into one attrset, and it has no identity outside its parent.

        In yen, a named submodule is a kind. `user` above is one: each user is an instance with a name, a ref to
        its host (`on = yen.kinds.host`), defaults (`shell`), and its own errors with a path. `spawns` makes each
        user a scope under its host, so aspects can be active on users, and queries can find them:
      ''
      (docs.value (map (s: s.id) result.scopes))
      ''
        A submodule with no names, like `services.nginx`, is a nested field. `firewall.enable` and `firewall.ports`
        above are one. For how `config` as a fixpoint compares, see [Fixpoints and dependencies](/principles/fixpoints/).
      ''
    ];

  checks =
    {
      result,
      variant,
      inputs,
      eq,
      yes,
      no,
      ...
    }:
    let
      t = inputs.nixpkgs.lib.types;
    in
    {
      nixos-style = eq (map (e: e.code) (variant "variants/nixos-style.nix").errors) ([
        "unknown-key"
        "unknown-key"
      ]);
      mkif = {
        t1 = yes (result.active.firewall."fleet:main/host:web");
        t2 = no (result.active.firewall."fleet:main/host:db");
      };
      nixos = eq (result.reduced.nixos) ({
        "fleet:main/host:web".networking.firewall.allowedTCPPorts = [ 443 ];
      });
      submodule-as-kind = eq (map (s: s.id) result.scopes) ([
        "fleet:main"
        "fleet:main/host:db"
        "fleet:main/host:web"
        "fleet:main/host:web/user:ana"
      ]);
      default = eq ((builtins.head (builtins.filter (s: s.kind == "user") result.scopes)).shell) ("bash");
      # the warning is true: nixpkgs composite types check only the outer shape
      nixpkgs-shallow = {
        t1 = yes ((t.listOf t.int).check [ "a" ]);
        t2 = yes ((t.attrsOf t.int).check { x = "a"; });
        t3 = yes ((t.submodule { options = { }; }).check { y = 1; });
        t4 = yes ((t.functionTo t.int).check (x: "a"));
        t5 = no (t.int.check "a");
      };
    };
}
