{
  title = "MCP server";
  description = "Agents ask a fleet over stdio JSON-RPC: schema, check, context, explain, stage, programs and stored queries.";
  section = "agents";
  order = 5;

  body =
    { docs, inputs, ... }:
    let
      tools = builtins.fromJSON (
        builtins.readFile (inputs.yen + "/templates/fleet/mcp/server/src/tools.json")
      );
    in
    [
      ''
        The reference fleet ships an MCP server: `templates/fleet/mcp/server`, a small Rust binary. It answers agents over stdio
        (JSON-RPC 2.0, one message per line) by running yen queries on the fleet. It serves the fleet in its directory.
      ''
      (docs.sh ''
        cd templates/fleet
        nix run .#yen-mcp
      '')
      ''
        ## Tools

        This table is read from the tool list the server embeds (`mcp/server/src/tools.json`) (${toString (builtins.length tools)} tools):
      ''
      (docs.table [ "Tool" "What it answers" ] (
        map (t: [
          "`${t.name}`"
          t.description
        ]) tools
      ))
      ''
        Each answer is `{ complete; result }`, or `{ complete = false; error }`. A timeout is never an empty answer.
        The fleet template ships a skill that teaches agents the order of calls, the answer shapes and the refusals:
        `.claude/skills/yen-mcp/SKILL.md`. A fleet test checks that it names every tool, and no other.
        Arguments reach Nix through a file and `builtins.fromJSON`, never through string interpolation.

        ## Register it

        Any MCP client that starts a stdio server can use it. For example, in an `mcpServers` config:
      ''
      (docs.code "json" ''
        { "mcpServers": { "yen": { "command": "nix", "args": [ "run", "/path/to/fleet#yen-mcp" ] } } }
      '')
      (docs.table
        [ "Variable" "Meaning" ]
        [
          [
            "`YEN_FLEET`"
            "the fleet directory (default: the working directory)"
          ]
          [
            "`YEN_FLAKE`"
            "its flake ref (default: from the git top)"
          ]
          [
            "`YEN_TIMEOUT`"
            "seconds per nix call (default 120)"
          ]
        ]
      )
      (docs.tip "Your own fleet" ''
        Copy `mcp/` and ${
          docs.fleet "modules/agent/mcp.nix" null "agent/mcp.nix"
        } into your fleet. The server needs only
        the queries of the other agent pages: `schema`, `check`, `context`, `explain`, stored queries, `stage` and `program`.
        `mcp/test.sh` drives every tool.
      '')
    ];

  checks =
    { inputs, ... }:
    {
      tools =
        builtins.length (
          builtins.fromJSON (builtins.readFile (inputs.yen + "/templates/fleet/mcp/server/src/tools.json"))
        ) == 14;
    };
}
