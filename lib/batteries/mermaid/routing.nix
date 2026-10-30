#: lib.batteries.mermaid.routing :: graph -> view -- routing at the kind level, with element counts
# a view of routing at the kind level: the kind of the giving scope -> sink -> the kind of the receiver, each edge
# labelled with its element count. Only elements given by aspects.
#   mermaid.flowchart { } (mermaid.routing yen.lib.graph)
let
  b = builtins;
  sorted =
    xs: b.sort b.lessThan (b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ] xs);
  isAspect = e: b.substring 0 7 e.origin == "aspect ";
in
g:
let
  kindOf = b.listToAttrs (
    map (s: {
      name = s.id;
      value = s.kind;
    }) g.scopes
  );
  given = b.filter isAspect g.edges;
  # edges "x>y" counted
  counted =
    f: from: to:
    map (
      k:
      let
        ab = b.filter b.isString (b.split ">" k);
      in
      {
        from = from (b.head ab);
        to = to (b.elemAt ab 1);
        label = toString (b.length (b.filter (e: f e == k) given));
      }
    ) (sorted (map f given));
in
{
  nodes =
    map (k: {
      id = "k:${k}";
      label = k;
      kind = k;
    }) (sorted (map (e: kindOf.${e.from}) given ++ map (e: kindOf.${e.to}) given))
    ++ map (s: {
      id = "s:${s}";
      label = s;
      kind = "sink";
    }) (sorted (map (e: e.sink) given));
  edges =
    counted (e: "${kindOf.${e.from}}>${e.sink}") (k: "k:${k}") (s: "s:${s}")
    ++ counted (e: "${e.sink}>${kindOf.${e.to}}") (s: "s:${s}") (k: "k:${k}");
}
