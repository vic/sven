# Transitive impact of a staged change, as dirty tokens. Builtins only.
# A token is "d:<scope>" (data of that scope changed) or "k:<sink>@<scope>" (the reduced value of that sink at that receiver changed).
let
  b = builtins;
  uniq =
    xs:
    b.attrNames (
      b.listToAttrs (
        map (x: {
          name = x;
          value = null;
        }) xs
      )
    );
  #: impactOf :: { edges; seeds; children; } -> { tokens; scopes; } -- every token the seeds make dirty, and the scopes they touch, sorted
  impactOf =
    {
      edges,
      seeds,
      children,
    }:
    let
      # P1: a dirty token read by an edge dirties that edge's sink at its receiver
      readers = b.foldl' (
        acc: e:
        b.foldl' (acc2: r: acc2 // { ${r} = (acc2.${r} or [ ]) ++ [ "k:${e.sink}@${e.to}" ]; }) acc e.reads
      ) { } edges;
      # P2: a dirty scope dirties the data of its children
      childrenOf =
        t:
        let
          m = b.match "d:(.*)" t;
        in
        if m == null then [ ] else map (c: "d:${c}") (children.${b.head m} or [ ]);
      next = t: (readers.${t} or [ ]) ++ childrenOf t;
      tokens = uniq (
        map (i: i.key) (
          b.genericClosure {
            startSet = map (t: { key = t; }) seeds;
            operator = i: map (key: { inherit key; }) (next i.key);
          }
        )
      );
      # the scope of "d:X" is X; the receiver of "k:n@R" is R (a sink key never contains "@")
      scopeOf =
        t:
        let
          d = b.match "d:(.*)" t;
        in
        if d != null then b.head d else b.head (b.match "k:[^@]*@(.*)" t);
    in
    {
      inherit tokens;
      scopes = uniq (map scopeOf tokens);
    };
in
{
  inherit impactOf;
}
