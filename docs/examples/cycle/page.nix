{
  title = "The cycle form";
  description = "A component asks the tree for data and gives 0 to n elements.";
  section = "behavior";
  order = 2;

  body =
    { docs, result, ... }:
    [
      ''
        Each key of an aspect gives one element. For 0 to n elements, or to ask the tree for data, write a component
        under `cycle`. As in [Cycle.js](https://cycle.js.org), a component is a function from sources to sinks.
        Its sources are `tree`, `scope` and one source for each sink. It returns sinks by name, and `tree` requests.
      ''
      (docs.file "modules/network.nix")
      ''
        The host has two guests, so the component gives two bridges:
      ''
      (docs.value result.flake.bridges)
      ''
        ## Tree requests

        A request is one question. `tree.select request` gives its answers: the request is its own name, so it has no
        string to mistype. Bind it in a `let` and use it twice.
      ''
      (docs.table
        [ "Request" "Answer" ]
        [
          [
            "`nearest = yen.kinds.environment`"
            "the nearest scope of that kind"
          ]
          [
            "`parent = true`"
            "the parent scope"
          ]
          [
            "`children = predicate`"
            "the children where the predicate holds"
          ]
          [
            "`scopesOf = instance`"
            "every scope of an instance"
          ]
          [
            "`holds = predicate`"
            "`true` or `false` at this scope"
          ]
          [
            "`instances = yen.kinds.host`"
            "every instance of that kind, with its data"
          ]
        ]
      )
      (docs.note "When to use it" ''
        Most aspects never need `cycle`. Use it when the number of elements depends on the tree, or when a component
        reports its own `errors`.
      '')
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
      bridges = eq (result.flake.bridges.server) ([
        "br-ci"
        "br-db"
      ]);
    };
}
