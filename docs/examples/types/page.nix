{
  title = "Types and defaults";
  description = "Any value with `check` is a type. `opt`, `maybe` and `derive` add defaults.";
  section = "concepts";
  order = 2;

  body =
    { docs, r, ... }:
    [
      ''
        yen has no type system of its own. A type is any value with `check = value: bool`.
        `lib.types` from nixpkgs works, a kind works (see [Instances and refs](/concepts/instances-refs/)),
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
        ]
      )
      (docs.fileWith "{9-14}" "modules/host.nix")
      ''
        Fields can nest. `settings.kernel.channel` is one field at a path, with its own type and default.
        An instance gives only what it needs:
      ''
      (docs.file "modules/hosts.nix")
      ''
        The read of a field looks at the instance first, then at the default, then checks the value:
      ''
      (docs.value r.flake.report)
      (docs.note "Derived defaults" ''
        `derive` gets the instance as `self`, so a default can read other fields or the instance name.
        An explicit value always wins: `db` sets its own `vpn`.
      '')
    ];

  checks =
    { r, ... }:
    {
      web =
        r.flake.report.web == {
          channel = "lts";
          jump = null;
          port = 22;
          tags = [ ];
          vpn = "vpn-web";
        };
      db =
        r.flake.report.db == {
          channel = "latest";
          jump = null;
          port = 2222;
          tags = [ ];
          vpn = "vpn-database";
        };
    };
}
