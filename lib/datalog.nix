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
  # least model of negation-free rules: pass over the rules until a pass adds nothing (at most one pass per rule)
  lm =
    rules:
    let
      step = b.foldl' (
        t2: r:
        if t2 ? ${r.head} || !b.all (p: t2 ? ${p}) (r.pos or [ ]) then t2 else t2 // { ${r.head} = true; }
      );
      go =
        t:
        let
          t2 = step t rules;
        in
        if b.length (b.attrNames t2) == b.length (b.attrNames t) then t else go t2;
    in
    go { };
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
  # proof tree of a true atom: the rule its certificate gives it. Its positive atoms have smaller stages, so a proof
  # never cycles (D4). A non-true atom is { status = "false" | "undefined"; }
  proof =
    rules: model: atom:
    let
      byAtom = b.listToAttrs (
        map (e: {
          name = k e.atom;
          value = e.rule;
        }) (certify rules).true
      );
      f = set model.false;
      go =
        a:
        if byAtom ? ${k a} then
          {
            atom = a;
            rule = byAtom.${k a};
            pos = map go (byAtom.${k a}.pos or [ ]);
            neg = byAtom.${k a}.neg or [ ];
          }
        else
          {
            atom = a;
            status = if f ? ${k a} then "false" else "undefined";
          };
    in
    go atom;
  # the prover: the stages of the well-founded model, I_{k+1} = W_P(I_k) (Van Gelder, Ross, Schlipf 1991, Def 3.4).
  # An atom's stage is the first k where it is decided: true by a rule whose body holds in I_k, false when it is in
  # the greatest unfounded set of I_k. A true atom carries a rule whose body was decided at smaller stages.
  # Undefined atoms are in neither list.
  certify =
    rules:
    let
      kr = keyed rules;
      byKey = index (atomsOf rules);
      keys = b.attrNames byKey;
      round =
        st:
        let
          fires = r: b.all (p: st.t ? ${p}) r.pos && b.all (n: st.f ? ${n}) r.neg;
          tp = b.filter (x: !(st.t ? ${x})) (map (r: r.head) (b.filter fires kr));
          # what may still hold: the least model of the rules not blocked by I_k; the rest is unfounded
          may = lm (
            map (r: r // { neg = [ ]; }) (
              b.filter (r: !b.any (p: st.f ? ${p}) r.pos && !b.any (n: st.t ? ${n}) r.neg) kr
            )
          );
          gus = b.filter (x: !(may ? ${x}) && !(st.f ? ${x})) keys;
          at =
            xs:
            b.listToAttrs (
              map (x: {
                name = x;
                value = st.k;
              }) xs
            );
        in
        {
          t = st.t // at tp;
          f = st.f // at gus;
          k = st.k + 1;
          done = tp == [ ] && gus == [ ];
        };
      go =
        st:
        let
          n = round st;
        in
        if n.done then st else go n;
      final = go {
        t = { };
        f = { };
        k = 0;
      };
      # the first rule of an atom whose body was decided before it
      ruleFor =
        x:
        let
          s = final.t.${x};
        in
        b.head (
          b.filter (
            i:
            let
              r = b.elemAt kr i;
            in
            r.head == x && b.all (p: (final.t.${p} or s) < s) r.pos && b.all (n: (final.f.${n} or s) < s) r.neg
          ) (b.genList (i: i) (b.length kr))
        );
    in
    {
      true = map (x: {
        atom = byKey.${x};
        stage = final.t.${x};
        rule = b.elemAt rules (ruleFor x);
      }) (b.attrNames final.t);
      false = map (x: {
        atom = byKey.${x};
        stage = final.f.${x};
      }) (b.attrNames final.f);
    };
  # the trusted checker, small and plain: a certificate is valid when each true atom has a rule of the program whose
  # positive atoms are true and negative atoms false at smaller stages, and every rule of a false atom has a positive
  # atom false at a stage no later, or a negative atom true at a smaller stage. Sound by induction on the stage (VRS
  # 1991, Thm 5.4); no stratification needed. True and false are disjoint without a check: an atom in both has a rule
  # whose blocking atom is also in both with a smaller sum of its two stages, and the sum cannot descend forever.
  checkCertificate =
    rules: cert:
    let
      norm = r: {
        inherit (r) head;
        pos = r.pos or [ ];
        neg = r.neg or [ ];
      };
      stages =
        es:
        b.listToAttrs (
          map (e: {
            name = k e.atom;
            value = e.stage;
          }) es
        );
      T = stages cert.true;
      U = stages cert.false;
      program = set (map norm rules);
      byHead = b.groupBy (r: k r.head) (map norm rules);
      before =
        m: s: x:
        m ? ${k x} && m.${k x} < s;
      notAfter =
        m: s: x:
        m ? ${k x} && m.${k x} <= s;
      supported =
        e:
        program ? ${k (norm e.rule)}
        && k e.rule.head == k e.atom
        && b.all (before T e.stage) (e.rule.pos or [ ])
        && b.all (before U e.stage) (e.rule.neg or [ ]);
      unfounded =
        e:
        b.all (r: b.any (notAfter U e.stage) r.pos || b.any (before T e.stage) r.neg) (
          byHead.${k e.atom} or [ ]
        );
    in
    {
      valid = b.all supported cert.true && b.all unfounded cert.false;
    };
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
