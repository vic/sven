{
  title = "The cycle form";
  description = "A component asks the tree for data and gives 0 to n elements.";
  section = "concepts";
  order = 12;

  body =
    { docs, r, ... }:
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
      (docs.value r.flake.bridges)
      ''
        ## Tree requests

        A request has a `category` and one question. `tree.select category` gives the answers.
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
        ]
      )
      (docs.note "When to use it" ''
        Most aspects never need `cycle`. Use it when the number of elements depends on the tree, or when a component
        reports its own `errors`.
      '')
    ];

  checks =
    { r, ... }:
    {
      bridges =
        r.flake.bridges.server == [
          "br-ci"
          "br-db"
        ];
    };
}
