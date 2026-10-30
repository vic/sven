{
  title = "Stored queries";
  description = "Name a question once with `yen.queries`, then ask it with `result.ask` from Nix, the CLI or an agent.";
  section = "query";
  order = 5;

  body =
    { docs, result, ... }:
    [
      ''
        A stored query names a question about the fleet. `result` is the eval result, the same `result` as outside the fleet: yen passes it when the query is asked with `result.ask`. The other formal args are its parameters:
        required, unless they have a default.
      ''
      (docs.file "modules/queries.nix")
      ''
        `result.queries` lists them with their parameters:
      ''
      (docs.value result.queries)
      ''
        `result.ask name args` answers:
      ''
      (docs.tabs [
        {
          label = ''ask "aspectsOn" { host = "web"; }'';
          body = docs.value (result.ask "aspectsOn" { host = "web"; });
        }
        {
          label = ''ask "hostsWith" { aspect = "git"; kind = "user"; }'';
          body = docs.value (
            result.ask "hostsWith" {
              aspect = "git";
              kind = "user";
            }
          );
        }
      ])
      ''
        A wrong call is an error record, never a throw: a missing parameter, an unknown one, or an unknown query with `near`.
      ''
      (docs.tabs [
        {
          label = "missing parameter";
          body = docs.value (result.ask "aspectsOn" { });
        }
        {
          label = "unknown query";
          body = docs.value (result.ask "aspectsOff" { host = "web"; });
        }
      ])
      (docs.sh ''nix eval --impure --json --expr '(import ./query.nix).ask "aspectsOn" { host = "web"; }' '')
      (docs.tip "Queries that synthesize" ''
        A stored query can return values that already meet your rules: a free port from [krn](/query/krn/), or the hosts where an
        aspect is safe from [Stage](/agents/stage/). The [MCP server](/agents/mcp/) serves stored queries to agents.
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
      ask = eq (result.ask "aspectsOn" { host = "web"; }) ([
        "git"
        "nginx"
      ]);
      optional = eq (result.queries.hostsWith) ({
        optional = [ "kind" ];
        required = [ "aspect" ];
      });
      missing = eq ((result.ask "aspectsOn" { }).code) ("missing-param");
      near = eq ((result.ask "aspectsOff" { host = "web"; }).near) ([ "aspectsOn" ]);
    };
}
