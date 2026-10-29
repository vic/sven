{
  title = "MCP server";
  description = "Agents ask a fleet over stdio JSON-RPC: schema, check, context, explain, stage, programs and stored queries.";
  section = "agents";
  order = 5;

  body =
    { docs, inputs, ... }:
    let
      script = builtins.readFile (inputs.yen + "/templates/fleet/mcp/yen-mcp.sh");
      lines = builtins.filter builtins.isString (builtins.split "\n" script);
      tool = l: builtins.match ''.*\{"name":"(yen_[a-z_]+)","description":"([^"]*)".*'' l;
      tools = builtins.filter (x: x != null) (map tool lines);
    in
    [
      ''
        The reference fleet ships an MCP server: `templates/fleet/mcp/yen-mcp.sh`. It answers agents over stdio
        (JSON-RPC 2.0, one message per line) by running yen queries on the fleet. It serves the fleet in its directory.
      ''
      (docs.sh ''
        cd templates/fleet
        nix run .#yen-mcp
      '')
      ''
        ## Tools

        This table is read from the server script itself (${toString (builtins.length tools)} tools):
      ''
      (docs.table [ "Tool" "What it answers" ] (
        map (t: [
          "`${builtins.elemAt t 0}`"
          (builtins.elemAt t 1)
        ]) tools
      ))
      ''
        Each answer is `{ complete; result }`, or `{ complete = false; error }`. A timeout is never an empty answer.
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
            "the fleet directory (default: the parent of `mcp/`)"
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
          builtins.filter (x: x != null) (
            map (l: builtins.match ''.*\{"name":"(yen_[a-z_]+)".*'' l) (
              builtins.filter builtins.isString (
                builtins.split "\n" (builtins.readFile (inputs.yen + "/templates/fleet/mcp/yen-mcp.sh"))
              )
            )
          )
        ) == 14;
    };
}
