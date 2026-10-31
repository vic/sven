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
  #: lib.datalog.isVar :: term -> bool -- the term is a variable { var = "X"; }
  isVar = t: b.isAttrs t && t ? var;
  # externals decide an atom on bound terms with a function: never a fact, never a head. The comparisons are built in;
  # they hold on terms of one type
  comparisons = {
    #: lib.datalog.comparisons.neq :: [ a b ] -> bool -- the two bound terms differ
    neq = ts: b.elemAt ts 0 != b.elemAt ts 1;
    #: lib.datalog.comparisons.lt :: [ a b ] -> bool -- a < b, for two ints or two strings; false on terms of two types
    lt =
      ts:
      let
        x = b.elemAt ts 0;
        y = b.elemAt ts 1;
      in
      (b.isInt x && b.isInt y || b.isString x && b.isString y) && x < y;
  };
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
  # an external atom's answer on the bound terms: true, false, or anything else, which is a fault
  call =
    ext: s: a:
    ext.${b.head a} (b.tail (sub s a));
  # the bindings of r's positive atoms (externals aside) over idx (relation -> tuples), left to right
  joins =
    ext: idx: r:
    b.foldl' (ss: a: b.concatMap (s: b.filter (x: x != null) (map (unify s a) (candidates idx s a))) ss)
      [
        { }
      ]
      (b.filter (a: !(ext ? ${b.head a})) (r.pos or [ ]));
  # the joins where every positive external is true and no negative one is
  bindings =
    ext: idx: r:
    b.filter (
      s:
      b.all (a: call ext s a == true) (b.filter (a: ext ? ${b.head a}) (r.pos or [ ]))
      && !b.any (a: call ext s a == true) (b.filter (a: ext ? ${b.head a}) (r.neg or [ ]))
    ) (joins ext idx r);
  # tuples by relation, and by the value at each position: a join reads only the tuples that can match a bound term
  byRel =
    tuples:
    b.mapAttrs (
      _: ts:
      {
        all = ts;
      }
      // b.listToAttrs (
        b.genList (i: {
          name = toString i;
          value = b.groupBy (t: k (b.elemAt t i)) (b.filter (t: b.length t > i) ts);
        }) (b.foldl' (m: t: if b.length t > m then b.length t else m) 0 ts)
      )
    ) (b.groupBy (x: b.head x) tuples);
  # the tuples an atom can match under s: the smallest bucket of a bound position, or all of its relation
  candidates =
    idx: s: a:
    let
      rel = idx.${b.head a} or { all = [ ]; };
      ground = t: !(isVar t) || s ? ${t.var};
      bucket = i: rel.${toString i}.${k (b.elemAt (sub s [ (b.elemAt a i) ]) 0)} or [ ];
      buckets = map bucket (b.filter (i: ground (b.elemAt a i)) (b.genList (i: i + 1) (b.length a - 1)));
    in
    b.foldl' (m: x: if b.length x < b.length m then x else m) rel.all buckets;
  # what may hold: the least model of the rules without their negative atoms, over the facts (an upper bound of the WFM)
  possible =
    ext: rules: known:
    let
      next = b.attrValues (
        index (known ++ b.concatMap (r: map (s: sub s r.head) (bindings ext (byRel known) r)) rules)
      );
    in
    if b.length next == b.length known then known else possible ext rules next;
  # Gelfond-Lifschitz reduct by the set i, then its least model
  gamma = rules: i: lm (b.filter (r: !b.any (n: i ? ${n}) (r.neg or [ ])) rules);
  # a literal (a relation called by reference, `yen.relations.serves h`) is its atom; an instance term is its
  # identity { kind; name; }, so two reads of one instance are one term. Any other atom stays as it is.
  term = t: if b.isAttrs t && t ? kind && t ? name then { inherit (t) kind name; } else t;
  atom = x: if b.isAttrs x && x ? atom then map term x.atom else x;
  # the rule as written, each atom normalized: an answer that names a rule shows the keys it was given
  rule =
    r:
    r
    // b.mapAttrs (n: v: if n == "head" then atom v else map atom v) (
      b.intersectAttrs {
        head = 0;
        pos = 0;
        neg = 0;
      } r
    );
  byAtom = m: m // { holds = a: m.holds (atom a); };
in
let
  raw = rec {
    inherit isVar comparisons;
    # ground instances of range-restricted rules over tuple facts: every instance whose positive atoms may hold.
    # The rest can never fire, so the well-founded model is the same. External atoms (ext: name -> terms -> bool) are
    # decided, then dropped. `faults`: the external atoms whose answer was not a bool
    #: lib.datalog.groundWith :: { name = terms -> bool; } -> [ rule ] -> [ atom ] -> { rules; faults; } -- the ground instances whose positive atoms may hold; external atoms decided, then dropped
    groundWith =
      ext: rules: facts:
      let
        idx = byRel (possible ext rules (b.attrValues (index facts)));
        isExt = a: ext ? ${b.head a};
        plain = a: !isExt a;
      in
      {
        rules = b.concatMap (
          r:
          map (s: {
            head = sub s r.head;
            pos = map (sub s) (b.filter plain (r.pos or [ ]));
            neg = map (sub s) (b.filter plain (r.neg or [ ]));
          }) (bindings ext idx r)
        ) rules;
        faults = b.concatMap (
          r:
          b.concatMap (
            s:
            map (sub s) (b.filter (a: isExt a && !b.isBool (call ext s a)) ((r.pos or [ ]) ++ (r.neg or [ ])))
          ) (joins ext idx r)
        ) rules;
      };
    #: lib.datalog.ground :: [ rule ] -> [ atom ] -> [ rule ] -- groundWith the comparisons
    ground = rules: facts: (groundWith comparisons rules facts).rules;
    #: lib.datalog.wfs :: [ rule ] -> { true; undefined; false; holds; } -- the well-founded model of ground rules (three values)
    wfs =
      rules:
      let
        atoms = atomsOf rules;
        kr = keyed rules;
        # lfp of gamma²: it grows from the empty set, so it stops when a round adds nothing
        lfp =
          a:
          let
            a2 = gamma kr (gamma kr a);
          in
          if b.length (b.attrNames a2) == b.length (b.attrNames a) then a else lfp a2;
        t = lfp { };
        g = gamma kr t; # what may hold
      in
      {
        true = b.filter (a: t ? ${k a}) atoms;
        undefined = b.filter (a: g ? ${k a} && !(t ? ${k a})) atoms;
        false = b.filter (a: !(g ? ${k a})) atoms;
        holds = a: t ? ${k a};
      };
    # the stable models: the true atoms plus each subset of the undefined ones that reproduces itself
    #: lib.datalog.stable :: [ rule ] -> [ [ atom ] ] -- the stable models, each a sorted list of true atoms
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
    #: lib.datalog.why :: [ rule ] -> model -> atom -> [ rule ] -- the rules that make the atom true in the model
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
    #: lib.datalog.proof :: [ rule ] -> model -> atom -> tree -- the proof tree of a true atom; { status; } for a false or undefined one
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
    #: lib.datalog.certify :: [ rule ] -> { true = [ { atom; stage; rule; } ]; false = [ { atom; stage; } ]; } -- the stages of the well-founded model, a certificate of each decided atom
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
        # the rules of each head, by index; the first rule of an atom whose body was decided before it
        byHead = b.groupBy (i: (b.elemAt kr i).head) (b.genList (i: i) (b.length kr));
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
              b.all (p: (final.t.${p} or s) < s) r.pos && b.all (n: (final.f.${n} or s) < s) r.neg
            ) byHead.${x}
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
    #: lib.datalog.checkCertificate :: [ rule ] -> certificate -> { valid; } -- the small trusted checker of a certificate
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
    #: lib.datalog.whyNot :: [ rule ] -> model -> atom -> [ { rule; missing; blocking; undefinedBody; } ] -- per rule with that head, the body atoms that stop it
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
    #: lib.datalog.judge :: [ rule ] -> atomFor -> atomAgainst -> string -- "supported", "refuted", "both", "neither" or "unknown" in the well-founded model
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
    #: lib.datalog.facts :: [ atom ] -> [ rule ] -- each atom as a rule with no body
    facts = map (a: {
      head = a;
    });
  };
in
# the same functions, on literals: rules, atoms and model lookups normalized once at the entry
raw
// {
  #: lib.datalog.atom :: literal -> atom -- the atom of a literal, its instance terms as { kind; name; }
  inherit atom;
  groundWith =
    ext: rules: facts:
    raw.groundWith ext (map rule rules) (map atom facts);
  ground = rules: facts: raw.ground (map rule rules) (map atom facts);
  wfs = rules: byAtom (raw.wfs (map rule rules));
  stable = rules: raw.stable (map rule rules);
  why =
    rules: model: a:
    raw.why (map rule rules) model (atom a);
  proof =
    rules: model: a:
    raw.proof (map rule rules) model (atom a);
  certify = rules: raw.certify (map rule rules);
  checkCertificate = rules: raw.checkCertificate (map rule rules);
  whyNot =
    rules: model: a:
    raw.whyNot (map rule rules) model (atom a);
  judge =
    rules: p: n:
    raw.judge (map rule rules) (atom p) (atom n);
  facts = as: raw.facts (map atom as);
}
