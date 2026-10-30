{
  title = "Predicates";
  description = "`at` takes a predicate: a function, a kind, an instance, an aspect, a list, and `all`, `not`, `within`, `has`.";
  section = "behavior";
  order = 3;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        A predicate is a function `scope: bool`. A kind ref, an instance ref, an aspect ref and a list are predicates too.
      ''
      (docs.table
        [ "Predicate" "Holds at a scope when" ]
        [
          [
            "`s: …`"
            "the function gives `true`"
          ]
          [
            "`yen.kinds.host`"
            "the scope is a host"
          ]
          [
            "`yen.host.web`"
            "the scope is the instance `web`"
          ]
          [
            "`yen.aspects.cuda`"
            "the aspect `cuda` is active there"
          ]
          [
            "`[ p q ]`"
            "any of the list holds"
          ]
          [
            "`all [ p q ]`"
            "all of the list hold"
          ]
          [
            "`not p`"
            "`p` does not hold"
          ]
          [
            "`within p`"
            "`p` holds at a proper ancestor"
          ]
          [
            "`has p`"
            "`p` holds at a child"
          ]
        ]
      )
      ''
        This example has two hosts and one guest (a VM) on `big`:
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/aspects.nix")
      ''
        Where each aspect is active (the output comes from `modules/report.nix`, an `entries` sink):
      ''
      (docs.value result.flake.active)
      ''
        Ask any predicate at a scope with `yen.lib.holds p scope`. A `spawns` function can use it too:
        structure can depend on which aspects are active at the parent.

        ## Cycles and mistakes

        Each scope computes each aspect ref once, so aspects that read aspects cost linear time.
        Refs can form cycles. A cycle through `not` has no answer: the aspects on it are not active,
        and the `undefined` query lists them. A cycle with no `not` is false.

        A value in `at` that is not a predicate, such as a string, is an error record. It is never a silent `false`.
      ''
      (docs.file "variants/cycle.nix")
      (docs.tabs [
        {
          label = "result.undefined";
          body = docs.value (variant "variants/cycle.nix").undefined;
        }
        {
          label = "result.errors";
          body = docs.value (variant "variants/cycle.nix").errors;
        }
      ])
      (docs.note "Well-founded semantics" ''
        This is the well-founded semantics of logic programs. You never get an arbitrary answer for a cycle:
        you get "undefined", and a query that says where.
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
      active = eq (result.flake.active) ({
        builder = [ "big" ];
        cuda = [ "big" ];
        monitored = [
          "big"
          "small"
        ];
        tiny = [ "small" ];
        vm-host = [ "big" ];
        vm-tools = [ "ci" ];
      });
      undefined = eq (builtins.length (variant "variants/cycle.nix").undefined) (4);
      at-string = eq (map (e: e.code) (variant "variants/cycle.nix").errors) ([ "at" ]);
    };
}
