{
  title = "Stored queries";
  description = "Name a question once with `yen.queries`, then ask it with `r.ask` from Nix, the CLI or an agent.";
  section = "query";
  order = 6;

  body =
    { docs, r, ... }:
    [
      ''
        A stored query names a question about the fleet. `r` is the eval result. The other formal args are its parameters:
        required, unless they have a default.
      ''
      (docs.file "modules/queries.nix")
      ''
        `r.queries` lists them with their parameters:
      ''
      (docs.value r.queries)
      ''
        `r.ask name args` answers:
      ''
      (docs.tabs [
        {
          label = ''ask "aspectsOn" { host = "web"; }'';
          body = docs.value (r.ask "aspectsOn" { host = "web"; });
        }
        {
          label = ''ask "hostsWith" { aspect = "git"; kind = "user"; }'';
          body = docs.value (
            r.ask "hostsWith" {
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
          body = docs.value (r.ask "aspectsOn" { });
        }
        {
          label = "unknown query";
          body = docs.value (r.ask "aspectsOff" { host = "web"; });
        }
      ])
      (docs.sh ''nix eval --impure --json --expr '(import ./query.nix).ask "aspectsOn" { host = "web"; }' '')
      (docs.tip "Queries that synthesize" ''
        A stored query can return values that already meet your rules: a free port from [krn](/query/krn/), or the hosts where an
        aspect is safe from [Stage](/agents/stage/). The [MCP server](/agents/mcp/) serves stored queries to agents.
      '')
    ];

  checks =
    { r, ... }:
    {
      ask =
        r.ask "aspectsOn" { host = "web"; } == [
          "git"
          "nginx"
        ];
      optional =
        r.queries.hostsWith == {
          optional = [ "kind" ];
          required = [ "aspect" ];
        };
      missing = (r.ask "aspectsOn" { }).code == "missing-param";
      near = (r.ask "aspectsOff" { host = "web"; }).near == [ "aspectsOn" ];
    };
}
