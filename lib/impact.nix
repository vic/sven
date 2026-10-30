# Transitive impact of a staged change, as dirty tokens. Builtins only.
# A token is data, never a parsed string: { data = scope id; } (the scope's record), { sink; at; } (the reduced value of
# that sink at that receiver), { instance; name; } (an instance's declared data), { aspect; at; } (where an aspect is active).
let
  b = builtins;
  key = b.toJSON;
  # impactOf :: { edges; whole ? [ ]; seeds; } -> [ token ] -- every token the seeds make dirty, sorted by key
  # edges: [ { out; reads; } ]: `out` is dirty when one of `reads` is; whole: tokens dirty when anything is
  impactOf =
    {
      edges,
      whole ? [ ],
      seeds,
    }:
    let
      readers = b.foldl' (
        acc: e: b.foldl' (a: r: a // { ${key r} = (a.${key r} or [ ]) ++ [ e.out ]; }) acc e.reads
      ) { } edges;
      reached = b.genericClosure {
        startSet = map (t: {
          key = key t;
          inherit t;
        }) (seeds ++ (if seeds == [ ] then [ ] else whole));
        operator =
          i:
          map (t: {
            key = key t;
            inherit t;
          }) (readers.${i.key} or [ ]);
      };
    in
    map (i: i.t) (b.sort (x: y: x.key < y.key) reached);
in
{
  inherit impactOf;
}
