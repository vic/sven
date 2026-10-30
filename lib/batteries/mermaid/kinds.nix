#: lib.batteries.mermaid.kinds :: kinds -> view -- spawns between kinds, and fields that refer to a kind
# a view of the kinds: a solid edge is `spawns` (parent kind to child kind), a dotted edge a field that refers to a kind
#   mermaid.flowchart { } (mermaid.kinds yen.kinds)
let
  b = builtins;
  names = v: if b.isAttrs v then b.attrNames v else [ ];
in
kinds: {
  nodes = map (k: {
    id = "k:${k}";
    label = k;
    kind = "kind";
  }) (b.attrNames kinds);
  edges = b.concatLists (
    map (
      k:
      let
        d = kinds.${k};
      in
      map (c: {
        from = "k:${k}";
        to = "k:${c}";
      }) (names (d.spawns or { }))
      ++ b.concatMap (
        f:
        let
          t = d.fields.${f};
        in
        if b.isAttrs t && (t ? __kind || t ? __maybe && t.__maybe ? __kind) then
          [
            {
              from = "k:${k}";
              to = "k:${t.__kind or t.__maybe.__kind}";
              label = f;
              live = false;
            }
          ]
        else
          [ ]
      ) (names (d.fields or { }))
    ) (b.attrNames kinds)
  );
}
