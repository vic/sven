{
  title = "Queries";
  description = "`yen.lib.eval` gives queries, not one value: errors, graph, scopes, active, reduced, facts, and more.";
  section = "query";
  order = 1;

  body =
    { docs, r, ... }:
    [
      ''
        `(import yen).lib.eval module` gives a set of queries. Each one is lazy: you pay only for what you read.
        Every answer is plain data, so `builtins.toJSON` prints it. This small fleet answers each query below.
      ''
      (docs.file "modules/fleet.nix")
      (docs.table
        [ "Query" "Answer" ]
        [
          [
            "`errors`"
            "`[ { error; from; code; … } ]`, empty when the fleet is valid"
          ]
          [
            "`graph`"
            "`{ scopes; edges; }`: every scope and every routed element, with its `origin`"
          ]
          [
            "`scopes`"
            "the scopes in order"
          ]
          [
            "`active`"
            "aspect, then scope id, then `true` or `false`"
          ]
          [
            "`undefined`"
            "aspects that `at` cannot decide (a cycle through `not`)"
          ]
          [
            "`reduced`"
            "sink, then receiver id, then the value"
          ]
          [
            "`flake`"
            "the answer of `yen.flake`"
          ]
          [
            "`data`"
            "every instance's declared fields"
          ]
          [
            "`schema`"
            "every kind, aspect and invariant, as JSON-safe data"
          ]
          [
            "`declaredIn path`"
            "the files that answer a declaration path"
          ]
          [
            "`facts`"
            "the fleet as ground atoms, for Datalog"
          ]
          [
            "`context id { }`"
            "one scope: parent, children, aspects, what it gives and receives"
          ]
          [
            "`check`"
            "the invariants: see [Invariants](/query/invariants/)"
          ]
        ]
      )
      (docs.tabs [
        {
          label = "reduced";
          body = docs.value r.reduced;
        }
        {
          label = "graph.edges";
          body = docs.value r.graph.edges;
        }
        {
          label = "facts";
          body = docs.value r.facts;
        }
      ])
      ''
        ## One scope in context

        `r.context id { maxEdges; maxAspects; }` is what an agent or a person reads first about a scope.
        Each list says how much it shows of how much there is:
      ''
      (docs.value (r.context "fleet:main/host:web" { }))
      ''
        ## Which aspects reach this host?

        Each edge of `graph` has `origin`: the aspect that gave the element. "Which aspects reach `web`" is a filter,
        not a registry: `map (e: e.origin) (filter (e: e.to == "fleet:main/host:web") r.graph.edges)`.
      ''
      (docs.sh ''
        nix eval --impure --file query.nix errors
        nix eval --impure --json --file query.nix graph
        nix eval --impure --expr '(import ./query.nix).context "fleet:main/host:web" { }'
      '')
      (docs.note "query.nix" ''
        The commands above use a `query.nix` that returns `eval` of your modules. See [Project layout](/start/project-layout/).
      '')
    ];

  checks =
    { r, ... }:
    {
      reduced =
        r.reduced.packages."fleet:main/host:web" == [
          "git"
          "nginx"
        ];
      origins =
        builtins.sort builtins.lessThan (
          map (e: e.origin) (builtins.filter (e: e.to == "fleet:main/host:web") r.graph.edges)
        ) == [
          "aspect git"
          "aspect git"
          "aspect nginx"
        ];
      facts = builtins.elem "has:nginx:fleet:main/host:web" r.facts;
    };
}
