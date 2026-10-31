{
  title = "Stored queries";
  description = "Name a question once with `yen.queries`, then ask it with `result.ask` from Nix, the CLI or an agent.";
  section = "query";
  order = 5;

  body =
    { docs, result, ... }:
    let
      web = {
        kind = "host";
        name = "web";
      }; # an instance ref, as JSON gives it
    in
    [
      ''
        A stored query names a question about the fleet: `{ params; answer; }`. Each parameter has a type, and it is optional when
        the type has a default (`yen.lib.opt`). `answer` gets the parameters and `result`, the same eval result as outside the fleet.
        A parameter that names a kind, an instance or an aspect is a ref (`yen.kinds.host`, `yen.lib.kind`, `yen.lib.aspect`), never a name.
      ''
      (docs.file "modules/queries.nix")
      ''
        `result.queries` lists them with their parameters and types:
      ''
      (docs.value result.queries)
      ''
        `result.ask name args` checks each parameter, then answers. From JSON (the CLI, an agent), a ref is its identity:
        `{ kind; name; }` an instance, `{ kind; }` a kind, `{ aspect; }` an aspect.
      ''
      (docs.tabs [
        {
          label = ''ask "aspectsOn" { host = { kind = "host"; name = "web"; }; }'';
          body = docs.value (result.ask "aspectsOn" { host = web; });
        }
        {
          label = ''ask "hostsWith" { aspect.aspect = "git"; kind.kind = "user"; }'';
          body = docs.value (
            result.ask "hostsWith" {
              aspect.aspect = "git";
              kind.kind = "user";
            }
          );
        }
      ])
      ''
        A wrong call is an error record, never a throw: a missing parameter, an unknown one, a name where a ref belongs, or an
        unknown query with `near`.
      ''
      (docs.tabs [
        {
          label = "missing parameter";
          body = docs.value (result.ask "aspectsOn" { });
        }
        {
          label = "a name, not a ref";
          body = docs.value (result.ask "aspectsOn" { host = "web"; });
        }
        {
          label = "unknown query";
          body = docs.value (result.ask "aspectsOff" { host = web; });
        }
      ])
      (docs.sh ''nix eval --impure --json --expr '(import ./query.nix).ask "aspectsOn" { host = { kind = "host"; name = "web"; }; }' '')
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
    let
      web = {
        kind = "host";
        name = "web";
      };
    in
    {
      ask = eq (result.ask "aspectsOn" { host = web; }) ([
        "git"
        "nginx"
      ]);
      optional = eq (result.queries.hostsWith) ({
        optional = [ "kind" ];
        required = [ "aspect" ];
        types = {
          aspect = "an aspect";
          kind = "a kind";
        };
      });
      # negative control: a name where a ref belongs is refused
      name-not-ref = eq ((result.ask "aspectsOn" { host = "web"; }).code) ("ref");
      kind = eq (result.ask "hostsWith" {
        aspect.aspect = "git";
        kind.kind = "user";
      }) ([ "ana" ]);
      missing = eq ((result.ask "aspectsOn" { }).code) ("missing-param");
      near = eq ((result.ask "aspectsOff" { host = web; }).near) ([ "aspectsOn" ]);
    };
}
