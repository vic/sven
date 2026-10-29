{
  title = "About yen";
  description = "Where yen comes from, and what it is for: complete fleets that people understand and agents can work on.";
  section = "project";
  order = 1;

  body =
    { docs, ... }:
    [
      ''
        ## The goal

        yen is for complete fleets: many machines, many people, services that span hosts, environments with their own rules.
        Advanced and complex fleets, that a person can still read and understand.

        yen also treats agents as first-class members of the team that runs the infrastructure. An agent reads the same
        queries as a person: the schema, the errors, why an aspect is active. It proposes a change as data, the fleet
        stages it, checks the rules across machines, and refuses it with the reason. Nothing reaches a machine unchecked.
      ''
      (docs.cards [
        {
          title = "For people";
          icon = "open-book";
          body = "Four words: kinds, scopes, aspects, sinks. Plain Nix data. Every rule of how content moves is a sink you can read.";
        }
        {
          title = "For agents";
          icon = "rocket";
          body = "Every answer is JSON-safe data. Changes are staged, checked by invariants, and limited by grants. An MCP server answers.";
        }
      ])
      ''
        ## Lineage

        yen is the latest step of a line of projects, each one a lesson for the next.
      ''
      (docs.mermaid ''
        flowchart LR
          vix["vic/vix: vic's machines"] --> den["denful/den"]
          den --> gen["sini's gen-* libs"]
          den --> exp["vic's experiments: denful/nest, ned, dnzl"]
          gen --> ren["vic/ren"]
          exp --> ren
          ren --> yen["vic/yen"]
      '')
      (docs.table
        [ "Project" "What it gave" ]
        [
          [
            "[vic/vix](https://github.com/vic/vix)"
            "a real fleet: vic's machines, homes and dev environments. Today it runs on yen."
          ]
          [
            "[denful/den](https://github.com/denful/den)"
            "aspects: configuration as features that land where they apply"
          ]
          [
            "[sini's gen-* libs](https://github.com/sini/gen)"
            "the libraries of Den's next version (den-hoag on Gen): scopes, graphs, laws"
          ]
          [
            "[denful/nest](https://github.com/denful/nest), [ned](https://github.com/denful/ned), [dnzl](https://github.com/denful/dnzl)"
            "vic's experiments: Nest, CSS-like rules over a tree; Ned, inspired by Cycle.js"
          ]
          [
            "[vic/ren](https://github.com/vic/ren)"
            "the fleet template that yen's reference fleet models"
          ]
          [
            "vic/yen"
            "queries instead of merges, Cycle.js sources and sinks, Nix builtins only"
          ]
        ]
      )
      ''
        The [reference fleet](/reference/fleet-map/) shows every capability of Den, den-hoag and clan, and the advanced
        patterns of real fleets (vix, sini's and others), each with a check. [Contributing](/project/contributing/) says how to help.
      ''
    ];
}
