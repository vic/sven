# one pool, many agents: each element of sink `from` is a record `{ type; name; … }` (type: "skill", "mcp",
# "plugin", …); an agent takes the records of the types it reads, as `build` wants them (sini agent-extensions).
#   homeManager = ai.extensions { from = yen.kinds.user.sinks.agent-ext; types = [ "mcp" ];
#     build = mcps: { programs.claude-code.mcpServers = builtins.listToAttrs (map (m: { inherit (m) name; value = m.server; }) mcps); }; };
{
  from,
  types,
  build,
}:
{ sinks, ... }:
build (builtins.filter (e: builtins.elem e.type types) sinks.${from.__sink})
