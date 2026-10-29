{
  title = "Queries";
  description = "`yen.lib.eval` gives queries, not one value: errors, graph, scopes, active, reduced, facts, and more.";
  section = "query";
  order = 1;

  body =
    {
      docs,
      r,
      variant,
      ...
    }:
    [
      ''
        `r = (import yen).lib.eval module` gives a set of queries. Each one is lazy: you pay only for what you read.
        `r` exists outside the fleet: in a script, a test, the CLI or an agent. Inside the fleet, see [below](#inside-the-fleet).
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
      ''
        ## Inside the fleet

        A module never gets `r`: the fleet is what `r` is computed from. An element reads results through its args
        and `yen.lib`, where it runs:
      ''
      (docs.table
        [ "To read" "Inside the fleet" ]
        [
          [
            "a sink's reduced value"
            "a sink arg: `{ packages, ... }:` gets the value at the nearest receiver of `packages`"
          ]
          [
            "the nearest scope of a kind"
            "a kind arg: `{ host, ... }:`"
          ]
          [
            "this scope, its parent"
            "`{ scope, ... }:`, then `scope.parent`"
          ]
          [
            "the children where a predicate holds"
            "`yen.lib.children p scope`"
          ]
          [
            "whether a predicate holds here"
            "`yen.lib.holds p scope`"
          ]
          [
            "the scopes of an instance"
            "`yen.lib.scopesOf instance`"
          ]
          [
            "the whole fleet"
            "`yen.lib.graph`, `yen.lib.schema`, `yen.lib.declaredIn`, `yen.lib.labels`"
          ]
        ]
      )
      (docs.file "variants/inside.nix")
      (docs.value (variant "variants/inside.nix").reduced.out."fleet:main".inside)
      (docs.note "Not inside" ''
        `errors`, `check`, `context`, `explain` and `impact` read the errors, and an element that reads the errors
        could change them. They exist only on `r`. A stored query gets `r` when it is asked from outside:
        see [Stored queries](/query/stored-queries/). A [cycle](/concepts/cycle/) also asks the tree with `tree`.
      '')
    ];

  checks =
    { r, variant, ... }:
    {
      inside =
        (variant "variants/inside.nix").reduced.out."fleet:main".inside == {
          web = {
            nginx = true;
            packages = [
              "git"
              "nginx"
            ];
            parent = "fleet:main";
            users = [ "ana" ];
          };
        }
        && (variant "variants/inside.nix").errors == [ ];
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
