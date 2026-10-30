#: lib.batteries.mermaid.sinks :: { schema; graph; } -> view -- sink keys that give to other sinks, and out to the flake outputs
# a view of the sinks: a dashed edge is a sink key that gives to another sink (labelled with the kind), a solid edge
# `out` to the flake outputs (labelled with the receivers that build them). Reads `schema` and `graph` of `yen.lib`.
#   mermaid.flowchart { } (mermaid.sinks yen.lib)
let
  b = builtins;
  sorted =
    xs: b.sort b.lessThan (b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ] xs);
  take = n: xs: b.genList (b.elemAt xs) (if b.length xs < n then b.length xs else n);
  # at most six names, then how many more
  short =
    xs:
    let
      s = sorted xs;
    in
    b.concatStringsSep ", " (take 6 s)
    + (if b.length s > 6 then ", +${toString (b.length s - 6)}" else "");
in
{ schema, graph, ... }:
let
  nameOf = b.listToAttrs (
    map (s: {
      name = s.id;
      value = s.name;
    }) graph.scopes
  );
  decls = b.concatMap (
    k:
    map (n: {
      kind = k;
      name = n;
      feeds = b.filter (f: f != "out") schema.kinds.${k}.sinks.${n}.feeds;
      out = b.elem "out" schema.kinds.${k}.sinks.${n}.feeds;
    }) (b.attrNames schema.kinds.${k}.sinks)
  ) (b.attrNames schema.kinds);
  receiversOf = sink: map (e: nameOf.${e.to}) (b.filter (e: e.sink == sink) graph.edges);
in
{
  nodes =
    map (n: {
      id = "sink:${n}";
      label = n;
      kind = "sink";
    }) (sorted (map (d: d.name) decls ++ b.concatMap (d: d.feeds) decls))
    ++ [
      {
        id = "flake";
        label = "flake outputs";
        kind = "output";
      }
    ];
  edges = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ] (
    b.concatMap (
      d:
      map (t: {
        from = "sink:${d.name}";
        to = "sink:${t}";
        label = d.kind;
        live = false;
      }) d.feeds
      ++ (
        if d.out then
          [
            {
              from = "sink:${d.name}";
              to = "flake";
              label = short (receiversOf d.name);
            }
          ]
        else
          [ ]
      )
    ) decls
  );
}
