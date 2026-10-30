# a view of `yen.lib.graph`: who gives what to whom; an element given at its own scope is a loop, left out
let
  b = builtins;
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
in
g: {
  nodes = map (s: {
    inherit (s) id kind;
    label = "${s.kind} ${s.name}";
  }) g.scopes;
  edges = unique (
    map (e: {
      inherit (e) from to;
      label = e.sink;
    }) (b.filter (e: e.from != e.to) g.edges)
  );
}
