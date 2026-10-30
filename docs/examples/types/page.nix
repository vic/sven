{
  title = "Types and defaults";
  description = "Any value with `check` is a type. `opt`, `maybe` and `derive` add defaults.";
  section = "model";
  order = 2;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        yen has no type system of its own. A type is any value with `check = value: bool`.
        `lib.types` from nixpkgs works, a kind works (see [Instances and refs](/model/instances-refs/)),
        and `yen.lib.is` makes a type from any function.
      ''
      (docs.table
        [ "Constructor" "Default" ]
        [
          [
            "`lib.types.str`, any type"
            "none: the field is required"
          ]
          [
            "`yen.lib.opt type value`"
            "`value`"
          ]
          [
            "`yen.lib.maybe type`"
            "`null`"
          ]
          [
            "`yen.lib.derive type (self: …)`"
            "computed from the instance itself"
          ]
          [
            "`yen.lib.is (v: …)`"
            "none: a type from a check function"
          ]
          [
            "`yen.lib.listOf type`"
            "none: a list whose elements pass the type"
          ]
          [
            "`yen.lib.attrsOf type`"
            "none: an attrset whose values pass the type"
          ]
          [
            "`yen.lib.enum [ … ]`"
            "none: one of the listed values"
          ]
        ]
      )
      (docs.fileWith "{13-14}" "modules/host.nix")
      ''
        Fields can nest. `settings.kernel.channel` is one field at a path, with its own type and default.
        An instance gives only what it needs:
      ''
      (docs.file "modules/hosts.nix")
      ''
        The read of a field looks at the instance first, then at the default, then checks the value:
      ''
      (docs.value result.flake.report)
      ''
        A value that fails its type is an error record that names the field. `listOf` and `attrsOf` check every item,
        which the nixpkgs types of the same names do not (see [Modules](/principles/modules/)):
      ''
      (docs.file "variants/bad-values.nix")
      (docs.value (variant "variants/bad-values.nix").errors)
      (docs.note "Derived defaults" ''
        `derive` gets the instance as `self`, so a default can read other fields or the instance name.
        An explicit value always wins: `db` sets its own `vpn`.
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
      bad-values = eq (map (e: e.path) (variant "variants/bad-values.nix").errors) ([
        [ "labels" ]
        [
          "settings"
          "kernel"
          "channel"
        ]
      ]);
      web = eq (result.flake.report.web) ({
        channel = "lts";
        jump = null;
        labels = { };
        port = 22;
        tags = [ ];
        vpn = "vpn-web";
      });
      db = eq (result.flake.report.db) ({
        channel = "latest";
        jump = null;
        labels.role = "database";
        port = 2222;
        tags = [ ];
        vpn = "vpn-database";
      });
    };
}
