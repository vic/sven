{
  title = "Graphs";
  description = "Reachability, layers, cycles and paths over fleet data with `yen.lib.graphs`: deploy waves and impact.";
  section = "query";
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
        Fleet data is plain Nix, so a question about it is a function. `yen.lib.graphs` answers graph questions.
        It works on `succ`, an attrset from a node to its successors, or on `of nodes next`, a graph over instances whose
        answers are refs `{ kind; name; }`: a host is never named by a string. Every function sorts, so the order the data is
        written in never changes an answer.
      ''
      (docs.table
        [ "Function" "Answer" ]
        [
          [
            "`reach succ n`"
            "every node reachable from `n`"
          ]
          [
            "`reachers succ n`"
            "every node that reaches `n`"
          ]
          [
            "`transpose succ`"
            "the edges reversed"
          ]
          [
            "`topo succ`"
            "a topological order, or `{ ok = false; stuck; }` for a cycle"
          ]
          [
            "`layers succ`"
            "waves: each node after its successors"
          ]
          [
            "`sccs succ`, `cycles succ`"
            "strongly connected components, nodes on a cycle"
          ]
          [
            "`shortest succ a b`, `paths succ a b`"
            "the shortest path, all paths"
          ]
          [
            "`of nodes next`"
            "a graph over instances: every function above takes it, and answers with refs"
          ]
          [
            "`fromEdges es`"
            "`succ` from `[ { from; to; } ]`"
          ]
        ]
      )
      ''
        Hosts depend on hosts:
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/deploy.nix")
      (docs.value result.flake.deploy)
      ''
        The deploy waves as a diagram, from the same data:
      ''
      (docs.mermaid (
        builtins.concatStringsSep "\n" (
          [ "flowchart LR" ]
          ++ builtins.concatLists (
            builtins.genList (
              i:
              map (h: "  ${h} --> w${toString i}[\"wave ${toString (i + 1)}\"]") (
                builtins.elemAt result.flake.deploy.waves i
              )
            ) (builtins.length result.flake.deploy.waves)
          )
        )
      ))
      ''
        ## A cycle is an error

        A cycle is data, not a hang. `sccs` finds it, and the aspect gives an error record:
      ''
      (docs.file "variants/cycle.nix")
      (docs.value (map (e: e.error) (variant "variants/cycle.nix").errors))
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
      waves = eq (result.flake.deploy.waves) ([
        [
          "cache"
          "db"
        ]
        [ "api" ]
        [ "web" ]
        [ "lb" ]
      ]);
      impact = eq (result.flake.deploy.impact.db) ([
        "api"
        "lb"
        "web"
      ]);
      cycle = eq (map (e: e.error) (variant "variants/cycle.nix").errors) ([
        "deploy: a dependency cycle: api -> db -> lb -> web"
      ]);
    };
}
