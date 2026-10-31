# Graph algorithms over plain data. A graph is `succ`: an attrset from node to a list of successors, or `of nodes next`:
# a graph over instances, whose answers are refs { kind; name; }.
# Builtins only. Every result is in sorted node order, so file order never changes an answer.
let
  b = builtins;
  sort = b.sort b.lessThan;
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
  #: lib.graphs.nodesOf :: succ -> [ node ] -- every node of the graph, sorted, with or without edges
  nodesOf = succ: uniq (b.attrNames succ ++ b.concatLists (b.attrValues succ));
  next = succ: n: sort (succ.${n} or [ ]); # sorted: the order the data is written in never changes an answer
  # nodes reachable by one or more edges (genericClosure: no recursion depth limit)
  #: lib.graphs.reach :: succ -> node -> [ node ] -- the nodes reachable from node by one edge or more, sorted
  reach =
    succ: start:
    sort (
      map (x: x.key) (
        b.genericClosure {
          startSet = map (n: { key = n; }) (next succ start);
          operator = x: map (n: { key = n; }) (next succ x.key);
        }
      )
    );
  #: lib.graphs.transpose :: succ -> succ -- the graph with every edge reversed
  transpose =
    succ:
    b.listToAttrs (
      map (n: {
        name = n;
        value = sort (b.filter (m: b.elem n (next succ m)) (nodesOf succ));
      }) (nodesOf succ)
    );
  # a graph over refs (`of`): each node keyed by its identity, so two reads of one instance are one node
  key = v: b.toJSON { inherit (v) kind name; };
  # the answer with each node key as the node identity { kind; name; }
  back =
    g: v:
    if b.isString v then
      g.__nodes.${v} or v
    else if b.isList v then
      map (back g) v
    else if b.isAttrs v then
      b.mapAttrs (_: back g) v
    else
      v;
  # a function of succ, on a graph from `of` too: node arguments by key, the answer by identity
  on0 = f: g: if g ? __nodes then back g (f g.succ) else f g;
  on1 =
    f: g: n:
    if g ? __nodes then back g (f g.succ (key n)) else f g n;
  on2 =
    f: g: x: y:
    if g ? __nodes then back g (f g.succ (key x) (key y)) else f g x y;
in
let
  raw = rec {
    inherit nodesOf reach transpose;
    #: lib.graphs.fromEdges :: [ { from; to; } ] -> succ -- a graph from a list of edges
    fromEdges = es: b.mapAttrs (_: xs: sort (map (e: e.to) xs)) (b.groupBy (e: e.from) es);
    #: lib.graphs.reachers :: succ -> node -> [ node ] -- the nodes that reach node (its dependents, when succ is "depends on")
    reachers = succ: reach (transpose succ);
    #: lib.graphs.cycles :: succ -> [ node ] -- the nodes on a cycle
    cycles = succ: b.filter (n: b.elem n (reach succ n)) (nodesOf succ);
    #: lib.graphs.sccs :: succ -> [ [ node ] ] -- the strongly connected components with 2 or more nodes or a self loop, each sorted, by first node
    sccs =
      succ:
      let
        t = transpose succ;
        comp = n: sort (uniq ([ n ] ++ b.filter (m: b.elem m (reach t n)) (reach succ n)));
        # one of each component, by first node
        distinct =
          xss:
          b.attrValues (
            b.listToAttrs (
              map (xs: {
                name = b.concatStringsSep "\n" xs;
                value = xs;
              }) xss
            )
          );
      in
      distinct (map comp (cycles succ));
    # Kahn: a node after all its successors (succ = "depends on"). Ties in name order. A cycle is data, not an error.
    #: lib.graphs.topo :: succ -> { ok; order; stuck; } -- each node after all its successors (Kahn); the nodes on a cycle stay in stuck
    topo =
      succ:
      let
        ns = nodesOf succ;
        step =
          acc: _:
          let
            ready = b.filter (n: !b.elem n acc.done && b.all (m: b.elem m acc.done) (next succ n)) acc.left;
          in
          if ready == [ ] then
            acc
          else
            {
              done = acc.done ++ [ (b.head ready) ];
              left = b.filter (n: n != b.head ready) acc.left;
            };
        r = b.foldl' step {
          done = [ ];
          left = ns;
        } ns;
      in
      {
        ok = r.left == [ ];
        order = r.done;
        stuck = r.left;
      };
    #: lib.graphs.layers :: succ -> [ [ node ] ] -- waves: each node in the first wave after all its successors
    layers =
      succ:
      let
        ns = nodesOf succ;
        go =
          acc: _:
          let
            placed = b.concatLists acc;
            ready = b.filter (n: !b.elem n placed && b.all (m: b.elem m placed) (next succ n)) ns;
          in
          if ready == [ ] then acc else acc ++ [ ready ];
      in
      b.foldl' go [ ] ns;
    #: lib.graphs.shortest :: succ -> from -> to -> [ node ] or null -- the shortest path by edges (breadth first), from first, to last
    shortest =
      succ: from: to:
      let
        bfs = b.genericClosure {
          startSet = [
            {
              key = from;
              path = [ from ];
            }
          ];
          operator =
            x:
            map (n: {
              key = n;
              path = x.path ++ [ n ];
            }) (next succ x.key);
        };
        hit = b.filter (x: x.key == to) bfs;
      in
      if hit == [ ] then null else (b.head hit).path;
    #: lib.graphs.paths :: succ -> from -> to -> [ [ node ] ] -- every simple path from from to to
    paths =
      succ: from: to:
      let
        go =
          seen: n:
          if n == to then
            [ [ n ] ]
          else
            b.concatMap (m: if b.elem m seen then [ ] else map (p: [ n ] ++ p) (go (seen ++ [ m ]) m)) (
              next succ n
            );
      in
      if from == to then [ [ from ] ] else go [ from ] from;
  };
in
raw
// {
  #: lib.graphs.of :: [ ref ] -> (ref -> [ ref ]) -> graph -- a graph over instances: the nodes and each node's successors; every function here takes it, and answers with refs { kind; name; }
  of = nodes: next: {
    __nodes = b.listToAttrs (
      map (n: {
        name = key n;
        value = { inherit (n) kind name; };
      }) (nodes ++ b.concatMap next nodes)
    );
    succ = b.listToAttrs (
      map (n: {
        name = key n;
        value = map key (next n);
      }) nodes
    );
  };
  transpose = g: if g ? __nodes then g // { succ = transpose g.succ; } else transpose g;
  nodesOf = on0 raw.nodesOf;
  cycles = on0 raw.cycles;
  sccs = on0 raw.sccs;
  topo = on0 raw.topo;
  layers = on0 raw.layers;
  reach = on1 raw.reach;
  reachers = on1 raw.reachers;
  shortest = on2 raw.shortest;
  paths = on2 raw.paths;
}
