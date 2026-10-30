#: lib.batteries.ai.extensions :: { from; types; build; } -> key value -- the records of the given types from a shared pool, as build wants them
# one pool, many agents: each element of sink `from` is a record `{ type; name; … }` (type: "skill", "mcp",
# "plugin", …) or a list of them (`ai.skills dir` gives a list); an agent takes the records of the types it reads, as
# `build` wants them (sini agent-extensions).
#   homeManager = ai.extensions { from = yen.kinds.user.sinks.agent-ext; types = [ "mcp" ];
#     build = mcps: { programs.claude-code.mcpServers = builtins.listToAttrs (map (m: { inherit (m) name; value = m.server; }) mcps); }; };
{
  from,
  types,
  build,
}:
{ sinks, ... }:
let
  b = builtins;
  records = b.concatMap (e: if b.isList e then e else [ e ]) sinks.${from.__sink};
in
build (b.filter (e: b.elem e.type types) records)
