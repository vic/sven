# Ground Datalog with negation. A rule is { head; pos ? [ ]; neg ? [ ]; }: head holds when every pos atom holds and
# no neg atom holds. An atom is any JSON value (a string, or a tuple `[ rel t… ]`), keyed by `toJSON`.
# Semantics: the well-founded model (Van Gelder, Ross, Schlipf 1991), by the alternating fixpoint: three values,
# total, no strata needed. `stable` gives the stable models (Gelfond, Lifschitz 1988) for choice: 2^|undefined|.
# Builtins only.
let
  b = builtins;
  k = b.toJSON;
  index =
    xs:
    b.listToAttrs (
      map (x: {
        name = k x;
        value = x;
      }) xs
    );
  set = xs: b.mapAttrs (_: _: true) (index xs);
  # every atom once, in key order
  atomsOf =
    rules: b.attrValues (index (b.concatMap (r: [ r.head ] ++ r.pos or [ ] ++ r.neg or [ ]) rules));
  # rules with every atom as its key: the fixpoints below work on strings only
  keyed = map (r: {
    head = k r.head;
    pos = map k (r.pos or [ ]);
    neg = map k (r.neg or [ ]);
  });
  # least model of negation-free rules: a fixpoint, bounded by the number of rules
  lm =
    rules:
    let
      step =
        t: _:
        b.foldl' (
          t2: r:
          if t2 ? ${r.head} || !b.all (p: t2 ? ${p}) (r.pos or [ ]) then t2 else t2 // { ${r.head} = true; }
        ) t rules;
    in
    b.foldl' step { } (b.genList (i: i) (b.length rules + 1));
  # ── the grounder: a variable is { var = "X"; }, every other term a constant (int, string, bool) ──
  isVar = t: b.isAttrs t && t ? var;
  # comparisons hold on ground terms of one type; they filter bindings, never facts
  comparisons = {
    neq = x: y: x != y;
    lt = x: y: (b.isInt x && b.isInt y || b.isString x && b.isString y) && x < y;
  };
  isCmp = a: comparisons ? ${b.head a};
  bind =
    s: t: v:
    if isVar t then
      (
        if !(s ? ${t.var}) then
          s // { ${t.var} = v; }
        else if s.${t.var} == v then
          s
        else
          null
      )
    else if t == v then
      s
    else
      null;
  unify =
    s: atom: tuple:
    if b.length atom != b.length tuple then
      null
    else
      b.foldl' (acc: i: if acc == null then null else bind acc (b.elemAt atom i) (b.elemAt tuple i)) s (
        b.genList (i: i) (b.length atom)
      );
  sub = s: map (t: if isVar t then s.${t.var} else t);
  holdsCmp =
    s: a:
    let
      x = sub s a;
    in
    comparisons.${b.head x} (b.elemAt x 1) (b.elemAt x 2);
  # the bindings of r's positive atoms over idx (relation -> tuples), left to right, comparisons applied
  bindings =
    idx: r:
    b.filter
      (
        s:
        b.all (holdsCmp s) (b.filter isCmp (r.pos or [ ]))
        && !b.any (holdsCmp s) (b.filter isCmp (r.neg or [ ]))
      )
      (
        b.foldl'
          (ss: a: b.concatMap (s: b.filter (x: x != null) (map (unify s a) (idx.${b.head a} or [ ]))) ss)
          [
            { }
          ]
          (b.filter (a: !isCmp a) (r.pos or [ ]))
      );
  byRel = b.groupBy (x: b.head x);
  # what may hold: the least model of the rules without their negative atoms, over the facts (an upper bound of the WFM)
  possible =
    rules: known:
    let
      next = b.attrValues (
        index (known ++ b.concatMap (r: map (s: sub s r.head) (bindings (byRel known) r)) rules)
      );
    in
    if b.length next == b.length known then known else possible rules next;
  # Gelfond-Lifschitz reduct by the set i, then its least model
  gamma = rules: i: lm (b.filter (r: !b.any (n: i ? ${n}) (r.neg or [ ])) rules);
in
rec {
  inherit isVar comparisons;
  # ground instances of range-restricted rules over tuple facts: every instance whose positive atoms may hold.
  # The rest can never fire, so the well-founded model is the same. Comparison atoms are applied, then dropped.
  ground =
    rules: facts:
    let
      idx = byRel (possible rules (b.attrValues (index facts)));
      plain = a: !isCmp a;
    in
    b.concatMap (
      r:
      map (s: {
        head = sub s r.head;
        pos = map (sub s) (b.filter plain (r.pos or [ ]));
        neg = map (sub s) (b.filter plain (r.neg or [ ]));
      }) (bindings idx r)
    ) rules;
  wfs =
    rules:
    let
      atoms = atomsOf rules;
      kr = keyed rules;
      t = b.foldl' (a: _: gamma kr (gamma kr a)) { } (b.genList (i: i) (b.length atoms + 1)); # lfp of gamma²
      g = gamma kr t; # what may hold
    in
    {
      true = b.filter (a: t ? ${k a}) atoms;
      undefined = b.filter (a: g ? ${k a} && !(t ? ${k a})) atoms;
      false = b.filter (a: !(g ? ${k a})) atoms;
      holds = a: t ? ${k a};
    };
  # the stable models: the true atoms plus each subset of the undefined ones that reproduces itself
  stable =
    rules:
    let
      w = wfs rules;
      subsets = b.foldl' (acc: x: acc ++ map (s: s ++ [ x ]) acc) [ [ ] ] w.undefined;
      ok =
        m:
        let
          s = set m;
        in
        b.attrNames (gamma (keyed rules) s) == b.attrNames s;
    in
    b.filter ok (map (s: b.sort (x: y: k x < k y) (w.true ++ s)) subsets);
  # the rules that make an atom true in a model (one step of provenance)
  why =
    rules: model: atom:
    let
      t = set model.true;
      f = set model.false;
    in
    b.filter (
      r: r.head == atom && b.all (p: t ? ${k p}) (r.pos or [ ]) && b.all (n: f ? ${k n}) (r.neg or [ ])
    ) rules;
  # proof tree of a true atom: its first supporting rule, recursively; a positive-support revisit is { cycle = true; };
  # a non-true atom is { status = "false" | "undefined"; }
  proof =
    rules: model: atom:
    let
      f = set model.false;
      go =
        seen: a:
        if !b.elem a model.true then
          {
            atom = a;
            status = if f ? ${k a} then "false" else "undefined";
          }
        else if b.elem a seen then
          {
            atom = a;
            cycle = true;
          }
        else
          let
            rs = why rules model a;
          in
          if rs == [ ] then
            {
              atom = a;
              rule = null;
              pos = [ ];
              neg = [ ];
            }
          else
            let
              r = b.head rs;
            in
            {
              atom = a;
              rule = r;
              pos = map (go (seen ++ [ a ])) (r.pos or [ ]);
              neg = r.neg or [ ];
            };
    in
    go [ ] atom;
  # why an atom is not true: per rule with that head, the body atoms that stop it firing
  whyNot =
    rules: model: atom:
    let
      t = set model.true;
      u = set model.undefined;
      rs = b.filter (r: r.head == atom) rules;
    in
    if t ? ${k atom} then
      [ ]
    else if rs == [ ] then
      [
        {
          rule = null;
          reason = "no rule has this head";
        }
      ]
    else
      map (r: {
        rule = r;
        missing = b.filter (p: !(t ? ${k p})) (r.pos or [ ]);
        blocking = b.filter (n: t ? ${k n}) (r.neg or [ ]);
        undefinedBody = b.filter (x: u ? ${k x}) ((r.pos or [ ]) ++ (r.neg or [ ]));
      }) rs;
  # verdict on a pair of atoms (atomPos for, atomNeg against) in the well-founded model:
  #   "supported" atomPos true, atomNeg not true    "refuted" atomNeg true, atomPos not true
  #   "both"      both true                          "unknown" otherwise, if either is undefined
  #   "neither"   both false
  judge =
    rules: atomPos: atomNeg:
    let
      w = wfs rules;
      p = w.holds atomPos;
      n = w.holds atomNeg;
      und = a: b.elem a w.undefined;
    in
    if p && n then
      "both"
    else if p then
      "supported"
    else if n then
      "refuted"
    else if und atomPos || und atomNeg then
      "unknown"
    else
      "neither";
  # facts: atoms with no body
  facts = map (a: {
    head = a;
  });
}
