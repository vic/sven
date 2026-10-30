# a view of the gates: the aspects that other aspects name in `at`, and what each gate's own `at` reads (kinds,
# instances, fact tests). The edge label is the operators on the way (`not`, `within`, `has`); dashed under a `not`.
#   mermaid.flowchart { } (mermaid.gates yen.aspects)
let
  b = builtins;
  sorted =
    xs: b.sort b.lessThan (b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ] xs);
  unique = b.foldl' (acc: x: if b.elem x acc then acc else acc ++ [ x ]) [ ];
  # `at` as refs, each with the operators above it
  walk =
    op: p:
    if b.isFunction p then
      [
        {
          inherit op;
          ref = "fact";
        }
      ]
    else if b.isList p then
      b.concatMap (walk op) p
    else if p ? __all then
      b.concatMap (walk op) p.__all
    else if p ? __not then
      walk (op ++ [ "not" ]) p.__not
    else if p ? __within then
      walk (op ++ [ "within" ]) p.__within
    else if p ? __has then
      walk (op ++ [ "has" ]) p.__has
    else if p ? __kind then
      [
        {
          inherit op;
          ref = "kind ${p.__kind}";
        }
      ]
    else if p ? __aspect then
      [
        {
          inherit op;
          ref = p.__aspect;
          aspect = true;
        }
      ]
    else if p ? kind && p ? name then
      [
        {
          inherit op;
          ref = "${p.kind}:${p.name}";
        }
      ]
    else
      [
        {
          inherit op;
          ref = "fact";
        }
      ];
in
aspects:
let
  refsOf = n: walk [ ] (aspects.${n}.at or [ ]);
  gated = b.concatMap (
    n:
    map (r: {
      from = r.ref;
      to = n;
    }) (b.filter (r: r.aspect or false) (refsOf n))
  ) (b.attrNames aspects);
  gates = sorted (map (x: x.from) gated);
  others = n: b.filter (r: !(r.aspect or false) && r.ref != "fact") (refsOf n);
in
{
  nodes =
    map (n: {
      id = "a:${n}";
      label = "${n} · ${toString (b.length (b.filter (x: x.from == n) gated))} gated";
      kind = "aspect";
    }) gates
    ++ map (r: {
      id = "r:${r}";
      label = r;
      kind = "ref";
    }) (sorted (b.concatMap (n: map (r: r.ref) (others n)) gates))
    ++ map (n: {
      id = "f:${n}";
      label = "fact test";
      kind = "ref";
    }) (b.filter (n: b.any (r: r.ref == "fact") (refsOf n)) gates);
  edges = unique (
    b.concatMap (
      n:
      map (r: {
        from =
          if r.aspect or false then
            "a:${r.ref}"
          else if r.ref == "fact" then
            "f:${n}"
          else
            "r:${r.ref}";
        to = "a:${n}";
        label = b.concatStringsSep " " r.op;
        live = !b.elem "not" r.op;
      }) (refsOf n)
    ) gates
  );
}
