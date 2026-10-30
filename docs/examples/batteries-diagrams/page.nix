{
  title = "Diagram and docs batteries";
  description = "mermaid views of scopes, kinds, gates and routes; tables, links that follow edits, doc lines checked against live names.";
  section = "batteries";
  route = "batteries/diagrams";
  order = 4;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    let
      d = result.flake.diagrams;
    in
    [
      ''
        Docs drift when they are written by hand. These batteries make them from the fleet itself: a renamed kind, a new
        host or a moved line shows up in the next `nix run .#write-files`, or fails the eval.

        | Battery | Gives |
        |---|---|
        | `mermaid.flowchart { direction; shapes; } view` | the text of a flowchart; a node that others name as `group` is a subgraph |
        | `mermaid.scopes { keep; label; group; edge; } graph` | a view of the scopes, each under its parent |
        | `mermaid.routes graph`, `mermaid.routing graph` | who gives what to whom; at kind level with counts |
        | `mermaid.kinds kinds`, `mermaid.sinks lib` | spawns and ref fields; sinks that give to sinks and to flake outputs |
        | `mermaid.gates aspects` | the aspects other aspects name in `at`, and what each reads (dashed under `not`) |
        | `docs.table head rows`, `docs.kinds kinds graph` | markdown tables |
        | `docs.links { root; base; }` | a reduce: links to the first line that contains a needle; a gone needle is an error |
        | `docs.vocabulary { what; names; lines; }` | errors: a live name with no doc line, a doc line with no live name |
        | `docs.templates { root; description; }` | flake templates from the directories that have a flake.nix (these docs use it) |

        A view is plain data, `{ nodes; edges; }`: make your own from anything and give it to `flowchart`.
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/diagrams.nix")
      ''
        ## Scopes, grouped by environment
      ''
      (docs.mermaid d.scopes)
      ''
        ## Kinds

        A dotted edge is a field that refers to a kind.
      ''
      (docs.mermaid d.kinds)
      ''
        ## Gates

        `monitored` reads `server`, and `legacy` under a `not`.
      ''
      (docs.mermaid d.gates)
      ''
        ## Routes
      ''
      (docs.mermaid d.routes)
      ''
        ## Routing by kind, and sinks
      ''
      (docs.mermaid d.routing)
      (docs.mermaid d.sinks)
      ''
        ## Tables, links and a vocabulary
      ''
      (docs.file "modules/docs.nix")
      result.flake.kinds
      ''

      ''
      result.flake.hosts
      (docs.value result.flake.templates)
      ''

        The link follows the line: `${result.flake.links.db-field}`. A new kind with no doc line fails:
      ''
      (docs.value (map (e: { inherit (e) error code; }) (variant "variants/new-kind.nix").errors))
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
    let
      d = result.flake.diagrams;
      has = s: t: builtins.replaceStrings [ s ] [ "" ] t != t; # literal substring
    in
    {
      scopes = {
        t1 = yes (has "subgraph" d.scopes);
        t2 = yes (has "[\"prod\"]" d.scopes);
        t3 = no ((has "fleet" d.scopes));
      };
      kinds = yes (has "-.->|\"db\"|" d.kinds);
      gates = yes (has "-.->|\"not\"|" d.gates);
      routes = yes (has "-->|\"inventory\"|" d.routes);
      inventory = eq (result.flake.inventory) ({
        dev = [ "lab" ];
        prod = [
          "pg"
          "web"
        ];
      });
      table = yes (has "| `host` | `db`, `environment` |  | `nixos` | 3 |" result.flake.kinds);
      routing = {
        t1 = yes (has "|\"1\"|" d.routing);
        t2 = yes (has "(\"inventory\")" d.routing);
      };
      sinks = yes (has "[(\"flake outputs\")]" d.sinks);
      hosts-table = yes (has "| lab | dev |" result.flake.hosts);
      templates = eq (result.flake.templates) ({ hello = "hello: the smallest flake"; });
      links = eq (result.flake.links.db-field) ("[`db`](fleet.nix#L23)");
      vocabulary = eq (map (e: e.code) (variant "variants/new-kind.nix").errors) ([ "doc-missing" ]);
    };
}
