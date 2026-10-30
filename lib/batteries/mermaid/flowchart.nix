# Mermaid flowcharts from views. A view is { nodes = [ { id; label; kind ? ; group ? ; } ]; edges = [ { from; to;
# label ? ; live ? ; } ]; }. `scopes` and `routes` make views of `yen.lib.graph`; you make your own views of any data.
#   text = mermaid.flowchart { direction = "TD"; shapes = with mermaid.shapes; { mac = round; }; } (mermaid.scopes yen.lib.graph);
# the text of one flowchart, without the ``` fence. A node that others name as `group` is a subgraph around them.
# `shapes` is keyed by a node's `kind`; other nodes are boxes.
let
  b = builtins;
  # md5 ids: any label is safe, and one id gets the same node in every view
  node = id: "n${b.substring 0 10 (b.hashString "md5" id)}";
  q = l: ''"${b.replaceStrings [ "\"" ] [ "'" ] l}"'';
in
{
  direction ? "LR",
  shapes ? { },
}:
view:
let
  box = n: node n.id + (shapes.${n.kind or ""} or (l: "[${l}]")) (q n.label);
  inside = p: b.filter (n: (n.group or null) == p.id) view.nodes;
  isGroup = n: b.any (m: (m.group or null) == n.id) view.nodes;
  draw =
    n:
    if isGroup n then
      [ "  subgraph ${node n.id} [${q n.label}]" ] ++ map (m: "    ${box m}") (inside n) ++ [ "  end" ]
    else
      [ "  ${box n}" ];
  edge =
    e:
    "  ${node e.from} ${if e.live or true then "-->" else "-.->"}${
        if (e.label or "") == "" then "" else "|${q e.label}|"
      } ${node e.to}";
in
b.concatStringsSep "\n" (
  [ "flowchart ${direction}" ]
  ++ b.concatMap draw (b.filter (n: (n.group or null) == null) view.nodes)
  ++ map edge view.edges
)
