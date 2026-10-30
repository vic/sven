# Mermaid flowcharts from views. A view is { nodes = [ { id; label; kind ? ; group ? ; } ]; edges = [ { from; to;
# label ? ; live ? ; } ]; }. `scopes` and `routes` make views of `yen.lib.graph`; you make your own views of any data.
#   text = mermaid.flowchart { direction = "TD"; shapes = with mermaid.shapes; { mac = round; }; } (mermaid.scopes yen.lib.graph);
let
  b = builtins;
  join = b.concatStringsSep;
  # md5 ids: any label is safe, and one id gets the same node in every view
  node = id: "n${b.substring 0 10 (b.hashString "md5" id)}";
  q = l: ''"${b.replaceStrings [ "\"" ] [ "'" ] l}"'';
  parentOf =
    id:
    let
      parts = b.filter b.isString (b.split "/" id);
    in
    join "/" (b.genList (b.elemAt parts) (b.length parts - 1));
  isUnder = s: b.match ".*/.*" s.id != null;
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
  label = s: "${s.kind} ${s.name}";
in
{
  # node shapes: a function from the quoted label to the mermaid node text
  shapes = {
    box = l: "[${l}]";
    round = l: "(${l})";
    subroutine = l: "[[${l}]]";
    parallelogram = l: "[/${l}/]";
    circle = l: "((${l}))";
    hexagon = l: "{{${l}}}";
    cylinder = l: "[(${l})]";
  };

  # the text of one flowchart, without the ``` fence. A node that others name as `group` is a subgraph around them.
  # `shapes` is keyed by a node's `kind`; other nodes are boxes.
  flowchart =
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
    join "\n" (
      [ "flowchart ${direction}" ]
      ++ b.concatMap draw (b.filter (n: (n.group or null) == null) view.nodes)
      ++ map edge view.edges
    );

  # every scope, under its parent
  scopes = g: {
    nodes = map (s: {
      inherit (s) id kind;
      label = label s;
    }) g.scopes;
    edges = map (s: {
      from = parentOf s.id;
      to = s.id;
    }) (b.filter isUnder g.scopes);
  };

  # who gives what to whom; an element given at its own scope is a loop, left out
  routes = g: {
    nodes = map (s: {
      inherit (s) id kind;
      label = label s;
    }) g.scopes;
    edges = unique (
      map (e: {
        inherit (e) from to;
        label = e.sink;
      }) (b.filter (e: e.from != e.to) g.edges)
    );
  };
}
