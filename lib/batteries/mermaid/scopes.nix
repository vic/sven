# a view of the scopes of `yen.lib.graph`, each under its parent. Options, all functions of a scope:
#   keep: draw it (default all) · label: its text (default "<kind> <name>") · group: the id of the scope it sits in
#   as a subgraph, or null · edge: draw the edge from its parent (default: when it has no group)
#   mermaid.flowchart { } (mermaid.scopes { group = s: if holds yen.kinds.host s then s.system.id else null; } yen.lib.graph)
let
  b = builtins;
  parentOf =
    id:
    let
      parts = b.filter b.isString (b.split "/" id);
    in
    b.concatStringsSep "/" (b.genList (b.elemAt parts) (b.length parts - 1));
  isUnder = s: b.match ".*/.*" s.id != null;
in
{
  keep ? _: true,
  label ? s: "${s.kind} ${s.name}",
  group ? _: null,
  edge ? s: group s == null,
}:
g:
let
  kept = b.filter keep g.scopes;
  ids = map (s: s.id) kept;
in
{
  nodes = map (
    s:
    {
      inherit (s) id kind;
      label = label s;
    }
    // (if group s == null then { } else { group = group s; })
  ) kept;
  edges = map (s: {
    from = parentOf s.id;
    to = s.id;
  }) (b.filter (s: isUnder s && b.elem (parentOf s.id) ids && edge s) kept);
}
