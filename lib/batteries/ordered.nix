# a reduce: elements `{ name; value; before ? [ ]; after ? [ ]; }` in an order that meets every before and after.
# value: the values in that order. A cycle, an unknown name or a name given twice is an error.
#   sinks.sections.reduce = ordered;
let
  b = builtins;
  graphs = import ../graphs.nix;
  pair = name: value: { inherit name value; };
in
es:
let
  vs = map (e: e.value) es;
  names = map (v: v.name) vs;
  known = n: b.elem n names;
  twice = b.filter (n: b.length (b.filter (m: m == n) names) > 1) names;
  unknown = b.filter (n: !known n) (b.concatMap (v: v.before or [ ] ++ v.after or [ ]) vs);
  # topo: a node waits for its successors. `after` is a successor; `before` makes this node a successor of the other
  succ = b.listToAttrs (
    map (
      v:
      pair v.name (
        b.filter known (v.after or [ ])
        ++ map (w: w.name) (b.filter (w: b.elem v.name (w.before or [ ])) vs)
      )
    ) vs
  );
  t = graphs.topo succ;
  byName = b.listToAttrs (map (v: pair v.name v.value) vs);
  err = code: msg: got: {
    error = "ordered: ${msg}";
    inherit code got;
  };
in
{
  value = map (n: byName.${n}) t.order;
  errors =
    (if twice == [ ] then [ ] else [ (err "ordered-twice" "names given twice" twice) ])
    ++ (
      if unknown == [ ] then
        [ ]
      else
        [ (err "ordered-unknown" "unknown names in before or after" unknown) ]
    )
    ++ (if t.ok then [ ] else [ (err "ordered-cycle" "a cycle among these names" t.stuck) ]);
}
