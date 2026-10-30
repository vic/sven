# yen.nix: builtins only. A query language for configurations: a Cycle.js loop over nested scopes.
# No throws: an error is an emission. No merge, no module system: every read is a query on the files that answer it.
# Entry: `(import ./yen.nix).lib.eval module`. A module is a path, a function or an attrset; `imports` nest, `_module.args` flow down.
let
  b = builtins;
  inherit (b)
    all
    any
    attrNames
    concatMap
    concatStringsSep
    elem
    filter
    foldl'
    functionArgs
    genericClosure
    groupBy
    head
    intersectAttrs
    isAttrs
    isFunction
    isList
    isPath
    isString
    length
    listToAttrs
    mapAttrs
    tail
    ;

  # ── tiny helpers (no nixpkgs) ──
  toList = v: if isList v then v else [ v ];
  first = p: foldl' (a: x: if a == null && p x then x else a) null; # stops calling p at the first hit
  uniq = foldl' (acc: x: if elem x acc then acc else acc ++ [ x ]) [ ];
  genAttrs =
    xs: f:
    listToAttrs (
      map (n: {
        name = n;
        value = f n;
      }) xs
    );
  keySet = xs: genAttrs xs (_: true);
  names = xs: attrNames (keySet xs); # sorted, no duplicates
  nest = path: v: if path == [ ] then v else { ${head path} = nest (b.tail path) v; };
  orNull = x: if x == null then [ ] else [ x ];
  optional = c: x: if c then [ x ] else [ ];
  words = s: filter isString (b.split " " s); # "a b" is [ "a" "b" ]
  isRef = v: isAttrs v && v ? kind && v ? name; # an instance, or a ref to one
  combinators = words "all not within has"; # `lib.all ps` is { __all = ps; }, and so on
  # keys the engine reads; the other keys of a sink, an aspect, a cycle output or a scope are data
  sinkMeta = words "at reduce of __sink";
  scopeKeys = words "kind name key parent path id up rup"; # the scope record sets these over the instance fields
  aspectMeta = words "at cycle order __aspect";
  outMeta = words "tree order";
  scopeMeta = words "kind name key parent path id up rup __here";
  requestKinds = words "nearest parent children scopesOf holds";
  # the facts yen extracts, with their arity: no rule derives them
  edbArity = {
    scope = 1;
    instance = 3;
    parent = 2;
    kind = 2;
    has = 2;
    edge = 3;
    error = 2;
    ref = 4;
    val = 3;
  };
  # the only keys a module, its `yen` and a kind declare; any other key is an error, never ignored
  moduleKeys = words "imports _module yen";
  yenKeys = words "kinds aspects helpers queries invariants relations labels flake"; # and the kind names
  kindKeys = words "fields spawns sinks";
  # s occurs in x, as text (no regex)
  hasInfix =
    s: x: any (i: b.substring i (b.stringLength s) x == s) (b.genList (i: i) (b.stringLength x + 1));
  # the routed elements whose aspect's trust is below t; `labels` gives each aspect its label
  floorOf =
    labels: edges: t:
    concatMap (
      e:
      let
        n = b.substring 7 (b.stringLength e.origin) e.origin;
        l = labels.${n};
      in
      optional (b.substring 0 7 e.origin == "aspect " && labels ? ${n} && (l.trust or 0) < t) (
        {
          edge = e;
          aspect = n;
          inherit (l) trust file prefix;
        }
        // intersectAttrs { by = null; } l
      )
    ) edges;
  uniqueBy =
    key: xs:
    map (i: i.x) (genericClosure {
      startSet = map (x: {
        key = key x;
        inherit x;
      }) xs;
      operator = _: [ ];
    });
  # an error record: `error` and `from` for people; `code path got want fix class near` for agents. `class` is
  # "fixable" (an edit to the data fixes it) or "authority" (no edit by this author can).
  err = from: msg: errWith from msg { };
  errWith =
    from: msg: x:
    {
      error = msg;
      inherit from;
      code = "error";
      path = [ ];
      class = "fixable";
    }
    // x;
  unknown =
    from: x: known: e:
    errWith from "no ${b.substring 8 99 e.code} ${x}" (e // { near = near x known; }); # code: "unknown-<what>"
  # edit distance (Levenshtein), for `near`: the known names a typo was probably meant to be
  dist =
    a: c:
    let
      n = b.stringLength c;
      ch = s: i: b.substring i 1 s;
      min = x: y: if x < y then x else y;
      range = b.genList (x: x);
      # deletion or insertion (+1), else substitution (+1 unless the characters match)
      cell =
        prev: r: i: j:
        min (min (b.elemAt prev (j + 1)) (b.elemAt r j) + 1) (
          b.elemAt prev j + (if ch a i == ch c j then 0 else 1)
        );
      row = prev: i: foldl' (r: j: r ++ [ (cell prev r i j) ]) [ (i + 1) ] (range n);
    in
    b.elemAt (foldl' row (range (n + 1)) (range (b.stringLength a))) n;
  near =
    x: cs:
    map (p: p.c) (
      b.sort (p: q: p.d < q.d || p.d == q.d && p.c < q.c) (
        filter (p: p.d <= 2 && p.d < b.stringLength x) (
          map (c: {
            inherit c;
            d = dist x c;
          }) cs
        )
      )
    );
  typeName =
    t:
    t.name or t.description
      or (if t ? __kind then "a ${t.__kind} ref" else "a value its check accepts");
  isLeaf =
    v: !isAttrs v || v ? check || v ? __kind || v ? __functor || (v.type or null) == "derivation";
  isType = t: isAttrs t && (t ? check || t ? __kind);
  # the kind a type refers to, through `maybe`; null when it is no ref
  refKind =
    t:
    if t ? __kind then
      t.__kind
    else if t ? __maybe then
      refKind t.__maybe
    else
      null;
  # a check that gives no bool (a curried gen-types check) fails, never throws; `boolCheck` names it in the error
  checkOf =
    t:
    if t ? __kind then
      (v: isAttrs v && (v.kind or null) == t.__kind)
    else
      (v: b.isBool (t.check v) && t.check v);
  boolCheck = t: v: t ? __kind || b.isBool (t.check v);
  get =
    path: v:
    foldl' (
      r: n: if r ? ok && isAttrs r.ok && !isLeaf r.ok && r.ok ? ${n} then { ok = r.ok.${n}; } else { }
    ) { ok = v; } path;
  attrsIn = xs: concatMap (x: if isAttrs x && !isLeaf x then attrNames x else [ ]) xs;

  # ── reduce strategies: elements in, { value; errors; } out ──
  mergeAt =
    path: a: bv:
    let
      subs = mapAttrs (
        n: v:
        let
          p = path ++ [ n ];
        in
        if !(a ? ${n}) then
          pure v
        else if isLeaf a.${n} || isLeaf v then
          {
            value = a.${n};
            errors = optional (a.${n} != v) (
              errWith "merge" "merge conflict at ${concatStringsSep "." p}" {
                code = "merge";
                path = p;
              }
            );
          }
        else
          mergeAt p a.${n} v
      ) bv;
    in
    {
      value = a // mapAttrs (_: x: x.value) subs;
      errors = concatMap (x: x.errors) (b.attrValues subs);
    };
  pure = value: {
    inherit value;
    errors = [ ];
  };
  reduce = {
    list = es: pure (map (e: e.value) es);
    set = es: pure (uniq (map (e: e.value) es));
    one = es: {
      value = if es == [ ] then null else (head es).value;
      errors = optional (length es != 1) (
        errWith "one" "one: got ${toString (length es)} elements" {
          code = "one";
          got = length es;
          want = 1;
        }
      );
    };
    merge = foldl' (
      acc: e:
      let
        m = mergeAt [ ] acc.value e.value;
      in
      m // { errors = acc.errors ++ m.errors; }
    ) (pure { });
    entries = pure;
  };
  # each built-in reduce is callable and carries its name, so `schema` can say which strategy a sink uses
  reduceNamed = mapAttrs (n: f: {
    __functor = _: f;
    name = n;
  }) reduce;
  static = {
    reduce = reduceNamed;
    is = check: { inherit check; }; # any check is a type: `yen.lib.is builtins.isString`
    opt = t: d: t // { default = d; };
    derive = t: f: t // { defaultFrom = f; }; # a default computed from the instance itself (Den schema defaults)
    maybe = t: {
      check = v: v == null || checkOf t v;
      default = null;
      __maybe = t; # the type it wraps: a maybe-ref is still a ref (refKind)
    };
    graphs = import ./lib/graphs.nix; # reach, transpose, topo, layers, sccs, cycles, paths, shortest over succ attrsets
    rdf = import ./lib/rdf.nix; # triples, ntriples, share: an eval result as sorted N-Triples with a content hash
    datalog = import ./lib/datalog.nix; # ground rules with negation: wfs (three values), stable, why
    batteries = import ./lib/batteries; # roles in, a yen module out: pool, gated, system; nixos.*
    # JSON-safe: functions and derivations become strings; toJSON then never fails
    jsonSafe =
      v:
      if isAttrs v && (v.type or null) == "derivation" then
        "<derivation ${v.name or "?"}>"
      else if isFunction v || isAttrs v && v ? __functor then
        "<function>"
      else if isPath v then
        toString v
      else if isList v then
        map static.jsonSafe v
      else if isAttrs v then
        mapAttrs (_: static.jsonSafe) v
      else
        v;
    agent = r: r.agent;
    # valid time: an instance with validFrom / validTo (ISO dates) holds at a date the caller passes; no clock in pure eval
    validAt =
      date: s:
      let
        bound = k: d: if (s.${k} or null) == null then d else s.${k};
      in
      bound "validFrom" "0000-00-00" <= date && date <= bound "validTo" "9999-12-31"; # absent or null: open
    krn = import ./lib/krn.nix; # µKanren: logic variables, unification, run, fresh, conde, appendo, facto
  };

  eval =
    root:
    let
      # ── load: imports are nested modules; `_module.args` flow down to them, like sources ──
      node =
        args: key: m:
        let
          f = if isPath m || isString m then import m else m;
          fa = if isFunction f then functionArgs f else { };
          missing = filter (a: !fa.${a} && !(args ? ${a})) (attrNames fa);
          v = if isFunction f then f (intersectAttrs fa args) else f;
          k = if isPath m || isString m then toString m else key;
        in
        {
          key = k;
        }
        // (
          if missing != [ ] then
            { error = "module ${k}: arg `${head missing}` has no answer"; }
          else
            {
              mod = v;
              args = args // (v._module.args or { }) // { inherit yen; };
            }
        );
      loaded = genericClosure {
        startSet = [ (node { inherit yen; } "root" root) ];
        operator =
          n:
          b.genList (i: node n.args "${n.key}/${toString i}" (b.elemAt n.mod.imports i)) (
            length (n.mod.imports or [ ])
          );
      };
      defs = map (n: n.mod.yen or { }) (filter (n: n ? mod) loaded);
      # the modules (file paths, or positions for inline modules) that answer a declaration path, in file order
      declaredIn =
        path:
        map (n: n.key) (
          filter (
            n:
            n ? mod
            &&
              (foldl' (a: k: if a != null && isAttrs a && a ? ${k} then a.${k} else null) (n.mod.yen or { }) path)
              != null
          ) loaded
        );
      filesOf =
        n:
        declaredIn [
          "aspects"
          n
        ];
      loadErrors = map (n: errWith "module" n.error { code = "module"; }) (filter (n: n ? error) loaded);

      # ── declarations: queries on the files, in file order. A leaf is the first answer; `at` is all answers ──
      # one lazy index over every file (zipAttrsWith): a lookup walks its path, never all files
      zipDefs = vs: {
        vals = vs;
        kids = b.zipAttrsWith (_: zipDefs) (filter (v: isAttrs v && !isLeaf v) vs);
      };
      index = zipDefs defs;
      answers =
        path:
        (foldl' (
          node: n:
          node.kids.${n} or {
            vals = [ ];
            kids = { };
          }
        ) index path).vals;
      atKey = path: path != [ ] && b.elemAt path (length path - 1) == "at";
      sinkKeyOf = path: length path == 3 && head path == "aspects" && elem (b.elemAt path 2) sinkNames; # several files may each give an element
      decl =
        path:
        let
          hs = answers path;
        in
        if atKey path then
          concatMap toList hs
        else if hs == [ ] then
          null
        else if isAttrs (head hs) && !isLeaf (head hs) then
          genAttrs (names (attrsIn hs)) (n: decl (path ++ [ n ]))
        else
          head hs;
      declErrors =
        path:
        let
          hs = answers path;
        in
        if atKey path || length hs < 2 || sinkKeyOf path then
          [ ]
        else if all (x: isAttrs x && !isLeaf x) hs then
          concatMap (n: declErrors (path ++ [ n ])) (names (attrsIn hs))
        else if all (x: x == head hs) hs then
          [ ]
        else
          [
            (errWith "declarations" "two answers for ${concatStringsSep "." path}" {
              code = "two-answers";
              inherit path;
              got = length hs;
              fix = "keep one answer for ${concatStringsSep "." path}: data never overrides data";
            })
          ];
      top = decl [ ];
      kinds = mapAttrs (
        k: d:
        d
        // {
          __kind = k;
          check = checkOf { __kind = k; };
        }
        // (if d ? sinks then { sinks = mapAttrs (n: v: v // { __sink = n; }) d.sinks; } else { }) # a sink is a ref: it carries its name
      ) (top.kinds or { }); # a kind is a type: its instances pass
      aspects = mapAttrs (n: a: a // { __aspect = n; }) (top.aspects or { });
      kindNames = attrNames kinds;
      aspectNames = attrNames aspects;

      # ── instance data: typed paths. Answers first, then the type defaults; a failed check reads as null ──
      typesAt =
        k: path:
        answers (
          [
            "kinds"
            k
            "fields"
          ]
          ++ path
        );
      # one walk per instance path gives its value and its errors
      inst =
        k: n: path:
        let
          ts = typesAt k path;
          tys = filter isType ts;
          hits = answers (
            [
              k
              n
            ]
            ++ path
          );
          d = first (t: isAttrs t && (t ? default || t ? defaultFrom)) ts;
          r =
            if hits != [ ] then
              { ok = head hits; }
            else if d != null then
              { ok = if d ? defaultFrom then d.defaultFrom instances.${k}.${n} else d.default; }
            else
              { };
          id = "${k}:${n}";
          p = concatStringsSep "." path;
          bad = first (t: !checkOf t r.ok) tys;
          notBool = first (t: !boolCheck t r.ok) tys;
          kr = first (t: refKind t != null) tys;
          fail = e: {
            value = null;
            errors = [ (errWith id e.error (removeAttrs e [ "error" ] // { inherit path; })) ];
          };
          sub = genAttrs (names (attrsIn (hits ++ ts))) (f: inst k n (path ++ [ f ]));
        in
        if tys != [ ] && !(r ? ok) then
          fail {
            error = "missing ${p}";
            code = "missing";
            want = typeName (head tys);
            fix = "set ${id}.${p}";
          }
        else if tys != [ ] && notBool != null then
          fail {
            error = "the check of ${p} gives a ${b.typeOf (notBool.check r.ok)}, not a bool";
            code = "check-not-bool";
            want = typeName notBool;
            fix = "make the check `v: bool`; a curried check needs its other argument first";
          }
        else if tys != [ ] && bad != null then
          fail {
            error = if kr != null then "${p} wants a ${refKind kr} ref" else "${p} fails its check";
            code = if kr != null then "ref" else "check";
            got = if isFunction r.ok then "<function>" else r.ok;
            want = typeName bad;
            fix =
              if kr != null then
                "use yen.${refKind kr}.<name>, not a string"
              else
                "give ${p} a value of type ${typeName bad}";
          }
        else if tys != [ ] then
          pure r.ok
        else if path != [ ] && ts == [ ] then
          fail {
            error = "unknown field ${p}";
            code = "unknown-field";
            near = near (b.elemAt path (length path - 1)) (
              names (attrsIn (typesAt k (b.genList (b.elemAt path) (length path - 1))))
            );
            fix = "declare yen.kinds.${k}.fields.${p}, or use a declared field";
          }
        else
          {
            value = mapAttrs (_: x: x.value) sub;
            errors = concatMap (x: x.errors) (b.attrValues sub);
          };
      instNames = k: attrNames (top.${k} or { });
      instances = mapAttrs (
        k: _:
        genAttrs (instNames k) (
          n:
          (inst k n [ ]).value
          // {
            kind = k;
            name = n;
          }
        )
      ) kinds;
      yen = instances // {
        inherit kinds aspects lib;
        helpers = top.helpers or { };
        queries = top.queries or { };
        invariants = top.invariants or { };
        relations = top.relations or { }; # user relations a rule derives: `<name>.arity`
        inherit labelTable;
      }; # declarations an agent or the docs read

      # ── the scope tree: nested cycles. key = what the parent spawned; identity = keys from the root ──
      mkScope =
        parent: kind: name: inst:
        let
          key = "${kind}:${name}";
          path = (if parent == null then [ ] else parent.path) ++ [ key ];
          s = inst // {
            inherit
              kind
              name
              key
              parent
              path
              ;
            __here = here s;
            id = concatStringsSep "/" path;
            up = (if parent == null then [ ] else parent.up) ++ [ s ];
            rup = [ s ] ++ (if parent == null then [ ] else parent.rup);
          }; # rup: nearest first, built once
        in
        s;
      spawnsOf = k: kinds.${k}.spawns or { };
      spawned = concatMap (k: attrNames (spawnsOf k)) kindNames;
      roots = concatMap (k: map (n: mkScope null k n instances.${k}.${n}) (instNames k)) (
        filter (k: kinds.${k} ? spawns && !elem k spawned) kindNames
      );
      childrenOf =
        s:
        concatMap (
          c:
          let
            made = (spawnsOf s.kind).${c} s;
          in
          if !isAttrs made then
            [ (errWith s.id "spawns.${c} gives no attrset" { code = "spawns"; }) ]
          else
            map (
              n:
              if any (x: x.key == "${c}:${n}") s.up then
                errWith s.id "instance ${c}:${n} twice on path" {
                  code = "cycle";
                  got = "${c}:${n}";
                }
              else if !isAttrs made.${n} then
                errWith s.id "spawns.${c}.${n} is no attrset" { code = "spawns"; }
              else
                mkScope s c n made.${n}
            ) (attrNames made)
        ) (attrNames (spawnsOf s.kind));
      item =
        c:
        if c ? error then
          {
            key = "error:${c.from}:${c.error}";
            e = c;
          }
        else
          {
            key = c.id;
            s = c;
          };
      tree = genericClosure {
        # C-level loop, breadth first: a parent comes before its children
        startSet = map item roots;
        operator = i: if i ? s then map item (childrenOf i.s) else [ ];
      };
      unsorted = map (i: i.s) (filter (i: i ? s) tree);
      treeErrors = map (i: i.e) (filter (i: i ? e) tree);
      parentId = s: if s.parent == null then "" else s.parent.id;
      byParent = groupBy parentId unsorted;
      below = s: byParent.${s.id} or [ ];

      # ── filter: every predicate is a function; refs, lists and the combinators are data the engine reads ──
      # Three values: true, false, null (undefined). An aspect ref is memoised per scope (`__here`), so nested refs cost
      # once. An aspect on a cycle of refs is evaluated with a stack: back on the stack through a `not`, the answer is
      # undefined (Gelder, Ross, Schlipf: well-founded semantics, a = not b, b = not a); with no `not`, false (unfounded).
      refsOf =
        p:
        if isList p then
          concatMap refsOf p
        else if !isAttrs p then
          [ ]
        else if p ? __aspect then
          [ p.__aspect ]
        else
          concatMap (k: refsOf p."__${k}") (filter (k: p ? "__${k}") combinators);
      refs = mapAttrs (_: a: map (r: { key = r; }) (refsOf (a.at or [ ]))) aspects; # once per aspect
      reach = mapAttrs (
        n: _:
        map (x: x.key) (genericClosure {
          startSet = refs.${n};
          operator = x: refs.${x.key};
        })
      ) aspects;
      cyclic = mapAttrs (n: rs: elem n rs) reach;
      tainted = mapAttrs (n: rs: cyclic.${n} || any (r: cyclic.${r}) rs) reach; # can be undefined: it reaches a cycle
      or3 =
        vs:
        if elem true vs then
          true
        else if elem null vs then
          null
        else
          false;
      and3 =
        vs:
        if elem false vs then
          false
        else if elem null vs then
          null
        else
          true;
      eval3 =
        stack: p: s:
        if isFunction p then
          p s
        else if isList p then
          (if length p == 1 then eval3 stack (head p) s else or3 (map (q: eval3 stack q s) p)) # `at` is always a list (a union over files): one entry is the common case
        else if p ? __all then
          and3 (map (q: eval3 stack q s) p.__all)
        else if p ? __not then
          (
            let
              v = eval3 (map (x: x // { neg = true; }) stack) p.__not s;
            in
            if v == null then null else !v
          )
        else if p ? __within then
          or3 (map (eval3 stack p.__within) (above s))
        else if p ? __has then
          or3 (map (eval3 stack p.__has) (below s))
        else if p ? __functor then
          p s
        else if p ? __kind then
          s.kind == p.__kind
        else if p ? __aspect then
          let
            q = p.__aspect;
            f = frame q s;
            hit = first (x: x.key == f.key) stack;
          in
          if hit != null then
            (if hit.neg then null else false)
          else if stack == [ ] || !cyclic.${q} then
            s.__here.${q} # per scope: structure may depend on presence (Den #525) without the whole tree
          else
            eval3 (stack ++ [ f ]) (aspects.${q}.at or [ ]) s
        else
          isRef p && s.kind == p.kind && s.name == p.name;
      frame = q: s: {
        key = "${q}@${s.id}";
        neg = false;
      };
      here = s: mapAttrs (q: a: eval3 [ (frame q s) ] (a.at or [ ]) s) aspects;
      holds =
        p: s:
        if isFunction p then
          p s
        else if p == [ ] then
          false
        else if isList p && length p == 1 && isFunction (head p) then
          (head p) s
        else
          eval3 [ ] p s == true; # fast paths: most predicates are functions, most sinks have no `at`
      # an aspect in the ref graph (it reads refs, or something reads it) goes through the memo; the others run directly
      inRefs = keySet (concatMap (n: if reach.${n} == [ ] then [ ] else [ n ] ++ reach.${n}) aspectNames);
      byScope =
        f: ss:
        listToAttrs (
          map (s: {
            name = s.id;
            value = f s;
          }) ss
        );
      active = mapAttrs (
        n: a: byScope (if inRefs ? ${n} then (s: s.__here.${n} == true) else holds (a.at or [ ])) unsorted
      ) aspects;
      undefined = concatMap (
        s:
        map (n: {
          aspect = n;
          scope = s.id;
        }) (filter (n: tainted.${n} && s.__here.${n} == null) aspectNames)
      ) unsorted;
      isPredicate =
        p:
        isFunction p || isList p || isAttrs p && (p ? __functor || p ? __kind || p ? __aspect || isRef p);
      # a typo must not read as false
      atErrors = concatMap (
        n:
        map (
          p:
          errWith "aspect ${n}" "`at` holds a ${b.typeOf p}, not a predicate" {
            code = "at";
            path = [
              "aspects"
              n
              "at"
            ];
            got = b.typeOf p;
            want = "a predicate: a function, a kind, instance or aspect ref, or a list";
          }
        ) (filter (p: !isPredicate p) (toList (aspects.${n}.at or [ ])))
      ) aspectNames;

      # ── components: one cycle per (aspect, scope). Its own tree requests feed its sources ──
      cycleOuts = mapAttrs (
        n: a:
        byScope (
          s:
          let
            o = a.cycle (sourcesAt s (o.tree or [ ]));
          in
          o
        ) (filter (s: active.${n}.${s.id}) unsorted)
      ) (b.removeAttrs aspects (filter (n: !(aspects.${n} ? cycle)) aspectNames));
      outAt = n: s: cycleOuts.${n}.${s.id} or { };

      # ── order: a sink every scope has; first answer, else 0. Siblings sort by (order, key); a parent sorts first ──
      orderNames = filter (n: aspects.${n} ? order || aspects.${n} ? cycle) aspectNames; # only these can answer `order`
      ordersAt =
        s:
        concatMap (
          n:
          if !active.${n}.${s.id} then
            [ ]
          else
            toList (aspects.${n}.order or [ ]) ++ toList ((outAt n s).order or [ ])
        ) orderNames;
      isNum = o: b.isInt o || b.isFloat o;
      orderErrors = map (s: errWith s.id "order is not a number" { code = "order"; }) (
        filter (s: !all isNum (ordersAt s)) unsorted
      );
      sortKeys = byScope (
        s:
        (if s.parent == null then [ ] else sortKeys.${s.parent.id})
        ++ [
          [
            (b.head (filter isNum (ordersAt s) ++ [ 0 ]))
            s.key
          ]
        ]
      ) unsorted;
      scopes =
        b.seq (foldl' (_: s: sortKeys.${s.id}) null unsorted) # force keys breadth first: no deep thunk chain
          (b.sort (x: y: sortKeys.${x.id} < sortKeys.${y.id}) unsorted);
      childrenAt = groupBy parentId scopes;

      # ── routing: nearest ancestor-or-self receiver (Cycle isolateSink tags the identity) ──
      sinkOf = s: k: (kinds.${s.kind}.sinks or { }).${k} or null;
      sinkKeys = d: attrNames (removeAttrs d sinkMeta);
      sinkNames = uniq (concatMap (k: attrNames (k.sinks or { })) (b.attrValues kinds));
      above = s: if s.parent == null then [ ] else s.parent.rup;
      receiverIn = k: first (r: sinkOf r k != null && holds ((sinkOf r k).at or (_: true)) r);
      given = concatMap (
        s:
        concatMap (
          n:
          let
            a = aspects.${n};
            o = outAt n s;
          in
          if !active.${n}.${s.id} then
            [ ]
          else
            concatMap (
              k:
              let
                hs = answers [
                  "aspects"
                  n
                  k
                ];
                one = length hs < 2 || all (x: isAttrs x && !isLeaf x) hs;
              in
              # data merges; functions from several files each apply
              b.genList (i: {
                origin = "aspect ${n}" + (if one then "" else "#${toString i}");
                key = k;
                from = s;
                value = if one then a.${k} else b.elemAt hs i;
              }) (if one then 1 else length hs)
            ) (attrNames (removeAttrs a aspectMeta))
            ++ concatMap (
              k:
              let
                vs = toList o.${k};
              in
              b.genList (i: {
                origin = "aspect ${n}";
                key = k;
                from = s;
                value = b.elemAt vs i;
                raw = i; # position: a cycle may emit many
              }) (length vs)
            ) (attrNames (removeAttrs o outMeta))
        ) aspectNames
      ) scopes;
      direct = concatMap (e: map (to: e // { inherit to; }) (orNull (receiverIn e.key e.from.rup))) (
        filter (e: e.key != "errors") given
      ); # nobody reads it: nothing happens
      fire = sink: r: {
        key = "${sink}@${r.id}";
        inherit sink r;
      };
      # what a fired sink gives on: each of its keys to that key's receiver (above it, for its own key)
      feeds =
        f:
        concatMap (
          k: map (to: { inherit k to; }) (orNull (receiverIn k (if k == f.sink then above f.r else f.r.rup)))
        ) (sinkKeys (sinkOf f.r f.sink));
      fired = genericClosure {
        # which (sink, receiver) pairs fire: existence only
        startSet = map (e: fire e.key e.to) direct;
        operator = f: map (x: fire x.k x.to) (feeds f);
      };
      fromSinks = concatMap (
        f:
        map (x: {
          origin = "sink ${f.sink}";
          key = x.k;
          from = f.r;
          inherit (x) to;
          value = (sinkOf f.r f.sink).${x.k};
        }) (feeds f)
      ) fired;
      routed = direct ++ fromSinks;
      byTo = groupBy (e: "${e.key}@${e.to.id}") routed;

      # ── sources at a scope (Cycle isolateSource): the tree driver and one source per sink ──
      isRen = n: n == "scope" || n == "sinks" || kinds ? ${n} || elem n sinkNames; # `tree` is a cycle source, never an element arg
      nearest = k: s: first (x: x.kind == k) s.rup;
      # what a tree request answers at a scope: a list, empty when nothing answers (Cycle: no source, no emission)
      answer =
        s: q:
        if q ? nearest then
          orNull (nearest q.nearest.__kind s)
        else if q ? parent then
          orNull s.parent
        else if q ? children then
          [ (lib.children q.children s) ]
        else if q ? scopesOf then
          [ (lib.scopesOf q.scopesOf) ]
        else
          [ (holds q.holds s) ];
      sourcesAt =
        s: requests:
        {
          scope = s;
          tree.select = c: concatMap (answer s) (filter (q: known q && q.category or null == c) requests);
        }
        // genAttrs sinkNames (
          n:
          let
            r = receiverIn n s.rup;
          in
          if r == null then [ ] else [ (memo.${n}.${r.id} or (reduceAt n r)).value ]
        ); # a receiver with no element yet reduces to its empty value
      known = q: any (k: q ? ${k}) requestKinds;
      requestErrors = concatMap (
        s:
        concatMap (
          n:
          map (_: errWith s.id "aspect ${n}: unknown tree request" { code = "tree-request"; }) (
            filter (q: !known q) (toList ((outAt n s).tree or [ ]))
          )
        ) (attrNames cycleOuts)
      ) unsorted;

      # ── map: fill the args yen answers; other args stay open (`__functionArgs`) ──
      # the scope an arg reads: the scope itself, the nearest instance of a kind, or a sink's receiver
      argScope =
        s: n:
        if n == "scope" || n == "sinks" then
          s
        else if kinds ? ${n} then
          nearest n s
        else if elem n sinkNames then
          receiverIn n s.rup
        else
          null;
      argAt =
        s: n:
        if n == "sinks" then
          [ (sinksAt s) ]
        else if n == "scope" || kinds ? ${n} then
          orNull (argScope s n)
        else
          (sourcesAt s [ ]).${n} or [ ];
      # the fixed arg `sinks`: each sink that has a receiver up the tree, read at the nearest one (as a named sink arg)
      sinksAt =
        s:
        mapAttrs (_: head) (
          b.removeAttrs (sourcesAt s [ ]) (
            filter (n: receiverIn n s.rup == null) sinkNames
            ++ [
              "scope"
              "tree"
            ]
          )
        );
      # nixpkgs lib.functionArgs rule: a functor with `__functionArgs` is a function. yen writes these (below) and reads them.
      isFn = f: isFunction f || f ? __functionArgs;
      fnArgs = f: f.__functionArgs or (functionArgs f);
      isAttrsFn = f: fnArgs f != { } || b.match ".*<attrspat.*" (b.toXML f) != null; # toXML only for `{ ... }:` vs `x:`
      fill =
        s: v:
        let
          fa = fnArgs v;
          mine = filter isRen (attrNames fa);
          asked = genAttrs mine (argAt s);
          none = filter (n: asked.${n} == [ ]) mine;
          missing = filter (n: !fa.${n}) none;
          got = mapAttrs (_: head) (removeAttrs asked none);
          rest = removeAttrs fa mine;
        in
        if !isFn v then
          { ok = v; }
        else if !isAttrsFn v then
          errWith s.id "bare function: wrap it as `{ ... }:`" {
            code = "bare-function";
            fix = "write `{ ... }:` so yen knows which args to fill";
          }
        else if fa ? tree then
          errWith s.id "arg `tree` is a cycle source" {
            code = "arg";
            want = "tree";
            fix = "ask the tree from a `cycle`: `cycle = { tree, ... }: { tree = [ … ]; <sink> = …; }`";
          }
        else if missing != [ ] then
          errWith s.id "arg `${head missing}` has no answer" {
            code = "arg";
            want = head missing;
            fix = "give `${head missing}` a default (`${head missing} ? null`) or make the element active only where it has an answer";
          } # Cycle: no source, no emission
        else if rest == { } then
          { ok = v got; }
        else
          {
            ok = {
              __functor = _: m: v (m // got);
              __functionArgs = rest;
            };
          };

      # ── the drivers ──
      idOf =
        e:
        if !isFn e.value then
          (if e ? raw then "${e.origin}|raw${toString e.raw}|${e.from.id}" else e.origin) # static content: once per receiver (Ren r13 rule 9)
        else
          "${e.origin}|"
          + concatStringsSep "," (map (n: (argScope e.from n).id or "") (attrNames (fnArgs e.value)));
      reduceAt =
        k: r:
        let
          d = sinkOf r k;
          es = uniqueBy (e: "${idOf e}@${r.id}") (byTo."${k}@${r.id}" or [ ]);
          filled = map (e: fill e.from e.value // { inherit e; }) es;
          okOf = x: x ? ok && (!(d ? of) || checkOf d.of x.ok);
          red = (d.reduce or reduce.list) (
            map (x: {
              from = x.e.from;
              value = x.ok;
            }) (filter okOf filled)
          );
          bad = map (
            x:
            if x ? error then
              removeAttrs x [ "e" ] // { error = "${x.e.origin}: ${x.error}"; } # the fill record keeps its code
            else
              errWith r.id "sink ${k}: element of ${x.e.origin} from ${x.e.from.id} fails `of`" { code = "of"; }
          ) (filter (x: !okOf x) filled);
        in
        {
          value = red.value;
          errors =
            bad
            ++ map (
              e:
              e
              // {
                from = r.id;
                sink = k;
              }
            ) red.errors;
        }; # a strategy cannot know its receiver: the engine names it
      # a record or a message; `from` is always the giver
      emitted = concatMap (
        e:
        let
          x = fill e.from e.value;
        in
        if x ? ok then
          map (
            m:
            if isAttrs m then
              errWith e.from.id (m.error or "error") (removeAttrs m [ "from" ])
            else
              err e.from.id m
          ) (toList x.ok)
        else
          [ (x // { error = "${e.origin}: ${x.error}"; }) ]
      ) (filter (e: e.key == "errors") given);

      # ── run: sinks feed drivers, drivers feed sources, Nix laziness closes the loop. Every output is a query ──
      receivers = k: filter (s: byTo ? "${k}@${s.id}") scopes;
      # one reduction per (sink, receiver), shared by the `reduced` query, the errors and every arg that reads the sink
      memo = genAttrs sinkNames (k: byScope (reduceAt k) (receivers k));
      reduced = mapAttrs (_: mapAttrs (_: x: x.value)) memo;
      reduceErrors = concatMap (k: concatMap (r: memo.${k}.${r.id}.errors) (receivers k)) sinkNames;
      graph = {
        scopes = map (s: { inherit (s) id kind name; }) scopes;
        edges = map (e: {
          sink = e.key;
          from = e.from.id;
          to = e.to.id;
          inherit (e) origin;
        }) routed;
      }; # origin: "aspect x" or "sink y": who gave it
      # ── facts and invariants: the fleet as typed atoms `[ rel t… ]`; `yen.invariants.<name>` gives Datalog rules over them.
      # A true `bad` atom is a violation; an undefined one (a cycle through `not`) is an incomplete answer, never a pass.
      # a field value: `[ "ref" FIELD ID KIND NAME ]` for a ref, `[ "val" FIELD ID VALUE ]` for a string, int or bool, one
      # per list element (a path by its string). A float, function or derivation has no fact, so it is an error: an absence never passes on it
      fieldAtoms = concatMap (
        s:
        concatMap (
          f:
          let
            one =
              x:
              if isRef x && isString x.kind then
                [
                  {
                    atom = [
                      "ref"
                      f
                      s.id
                      x.kind
                      x.name
                    ];
                  }
                ]
              else if isString x || b.isInt x || b.isBool x then
                [
                  {
                    atom = [
                      "val"
                      f
                      s.id
                      x
                    ];
                  }
                ]
              else if isPath x then
                [
                  {
                    atom = [
                      "val"
                      f
                      s.id
                      (toString x)
                    ];
                  }
                ] # a path is stated by its string
              else if b.isFloat x || isFunction x || isAttrs x && x.type or null == "derivation" then
                [
                  {
                    error = errWith s.id "field `${f}` holds a ${b.typeOf x}: no fact can state it" {
                      code = "unencodable";
                      path = [ f ];
                      got = b.typeOf x;
                      fix = "give the field a string, an int, a bool or a ref";
                    };
                  }
                ]
              else if isAttrs x then
                [
                  {
                    opaque = f;
                    inherit (s) id;
                  }
                ] # an attrset is data no fact states: a rule that must see it marks the verdict opaque (.41)
              else
                [ ];
          in
          if isList s.${f} then concatMap one s.${f} else one s.${f}
        ) (attrNames (removeAttrs s scopeMeta))
      ) unsorted;
      facts =
        map (s: [
          "scope"
          s.id
        ]) scopes
        ++ map (s: [
          "instance"
          s.id
          s.kind
          s.name
        ]) scopes # a ref names KIND NAME: this finds its scopes
        ++ map (s: [
          "parent"
          s.id
          s.parent.id
        ]) (filter (s: s.parent != null) scopes)
        ++ map (s: [
          "kind"
          s.kind
          s.id
        ]) scopes
        ++ concatMap (
          n:
          map (s: [
            "has"
            n
            s.id
          ]) (filter (s: active.${n}.${s.id}) unsorted)
        ) aspectNames
        ++ map (e: [
          "edge"
          e.sink
          e.from
          e.to
        ]) graph.edges
        ++ map (e: [
          "error"
          (e.code or "error")
          e.from
        ]) errorsFleet
        ++ concatMap (x: if x ? atom then [ x.atom ] else [ ]) fieldAtoms;
      check =
        let
          D = static.datalog;
          invs = yen.invariants;
          # rules are data (D3): a function is an error, so every rule a verdict uses can be read and certified
          rulesOf = n: if isList invs.${n} then invs.${n} else [ ];
          shapeErrors = map (
            n:
            errWith "invariant ${n}" "an invariant is a list of rules, not a ${b.typeOf invs.${n}}" {
              code = "invariant-function";
              path = [
                "invariants"
                n
              ];
              fix = "write the rules as data: [ { head = [ \"bad\" … ]; pos = [ … ]; neg = [ … ]; } ], with { var = \"X\"; }";
            }
          ) (filter (n: !isList invs.${n}) (attrNames invs));
          # externals decide atoms on bound terms: the comparisons, a relation with `holds = terms: bool`, and a
          # relation with `type` (rung 4: a type is a predicate, true when the term passes its check)
          externals =
            D.comparisons
            // mapAttrs (_: r: if r ? type then (ts: checkOf r.type (head ts)) else r.holds) (
              intersectAttrs (genAttrs (filter (n: yen.relations.${n} ? holds || yen.relations.${n} ? type) (
                attrNames yen.relations
              )) (_: null)) yen.relations
            );
          # every relation a rule may name: the extracted ones, the externals, and the user's; `bad` takes any arity
          arity =
            edbArity
            // mapAttrs (_: _: 2) D.comparisons
            // mapAttrs (_: r: if r ? type then 1 else r.arity) yen.relations;
          isAtom =
            a:
            isList a
            && a != [ ]
            && isString (head a)
            && all (t: isString t || b.isInt t || b.isBool t || D.isVar t) (tail a);
          isCmp = a: externals ? ${head a};
          varsOf = concatMap (a: map (t: t.var) (filter D.isVar (tail a)));
          # the first thing wrong with a rule, as { code; error; got; }, or null
          problem =
            r:
            let
              atoms = [ r.head ] ++ r.pos or [ ] ++ r.neg or [ ];
              bound = varsOf (filter (a: !isCmp a) (r.pos or [ ]));
              free = filter (x: !elem x bound) (
                varsOf ([ r.head ] ++ r.neg or [ ] ++ filter isCmp (r.pos or [ ]))
              );
              unknownRel = filter (a: !(arity ? ${head a}) && head a != "bad") atoms;
              wrongArity = filter (a: arity ? ${head a} && length (tail a) != arity.${head a}) atoms;
            in
            if !(isAttrs r && r ? head) || !all isAtom atoms then
              {
                code = "bad-atom";
                error = "an atom is a list [ rel t… ] of strings, ints, bools and { var = \"X\"; }";
                got = static.jsonSafe r;
              }
            else if edbArity ? ${head r.head} || isCmp r.head then
              {
                code = "edb-head";
                error = "a rule derives `${head r.head}`, a relation yen or a function decides: a rule never states it";
                got = r.head;
              }
            else if unknownRel != [ ] then
              {
                code = "unknown-relation";
                error = "no relation ${head (head unknownRel)}: declare it in yen.relations";
                got = head (head unknownRel);
                near = near (head (head unknownRel)) (attrNames arity);
              }
            else if wrongArity != [ ] then
              {
                code = "arity";
                error = "${head (head wrongArity)} takes ${toString arity.${head (head wrongArity)}} terms";
                got = head wrongArity;
              }
            else if free != [ ] then
              {
                code = "unsafe-rule";
                error = "variable ${head free} is not bound by a positive atom";
                got = free;
              }
            else
              null;
          checked = concatMap (
            n:
            map (r: {
              inherit n r;
              p = problem r;
            }) (rulesOf n)
          ) (attrNames invs);
          errors =
            shapeErrors
            ++ map (
              x:
              errWith "invariant ${x.n}" x.p.error (
                removeAttrs x.p [ "error" ]
                // {
                  path = [
                    "invariants"
                    x.n
                  ];
                }
              )
            ) (filter (x: x.p != null) checked)
            # a derived tuple of a user relation that fails the relation's check
            ++
              map
                (
                  a:
                  errWith "relation ${head a}" "${head a} derives ${b.toJSON (tail a)}, which fails its check" {
                    code = "relation-check";
                    got = a;
                    path = [
                      "relations"
                      (head a)
                    ];
                  }
                )
                (
                  filter (
                    a: yen.relations.${head a}.check or null != null && !checkOf yen.relations.${head a} (tail a)
                  ) m.true
                )
            # an external whose function gave no bool: the verdict cannot rest on it
            ++ map (
              a:
              errWith "relation ${head a}" "${head a} answers ${b.toJSON (tail a)} with no bool" {
                code = "external-not-bool";
                got = a;
                path = [
                  "relations"
                  (head a)
                ];
              }
            ) grounded.faults;
          grounded = D.groundWith externals (map (x: x.r) (filter (x: x.p == null) checked)) facts;
          ground = grounded.rules;
          key = b.toJSON;
          mentioned = keySet (map key (concatMap (r: r.pos ++ r.neg) ground));
          verdictProgram = ground ++ D.facts (filter (a: mentioned ? ${key a}) facts);
          m = D.wfs verdictProgram;
          # the staged certificate of the verdict (rung 3), and the plain checker's answer on it: valid, and it states
          # the same violations, with every undefined `bad` atom left out (incomplete)
          certificate = D.certify verdictProgram;
          certAtoms = es: b.sort b.lessThan (map (x: key x.atom) es);
          certified =
            (D.checkCertificate verdictProgram certificate).valid
            && certAtoms (filter (x: isBad x.atom) certificate.true) == b.sort b.lessThan (map key violations)
            && !any (a: elem (key a) (certAtoms (certificate.true ++ certificate.false))) incomplete;
          isBad = a: head a == "bad";
          violations = filter isBad m.true;
          incomplete = filter isBad m.undefined;
          # .41 (E1): a relation reached from `bad` through an even number of `not` must be complete. Yen's facts are,
          # but for a field value no fact states (an attrset): such a field read there makes the verdict opaque, not ok.
          # A node is a relation; a `val` atom with a constant field is its own node, `val/*` when the field is a variable
          node =
            a:
            if head a == "val" then "val/${if isString (b.elemAt a 1) then b.elemAt a 1 else "*"}" else head a;
          valid = map (x: x.r) (filter (x: x.p == null) checked);
          reached = keySet (
            map (x: x.key) (genericClosure {
              startSet = [
                {
                  key = "bad@0";
                  n = "bad";
                  odd = false;
                }
              ];
              operator =
                x:
                concatMap (
                  r:
                  let
                    next = flip: a: {
                      key = "${node a}@${if x.odd != flip then "1" else "0"}";
                      n = node a;
                      odd = x.odd != flip;
                    };
                  in
                  map (next false) (r.pos or [ ]) ++ map (next true) (r.neg or [ ])
                ) (filter (r: node r.head == x.n) valid);
            })
          );
          opaqueAt = groupBy (x: x.opaque) (filter (x: x ? opaque) fieldAtoms);
          opaque = map (f: {
            field = f;
            scopes = map (x: x.id) opaqueAt.${f};
          }) (filter (f: reached ? "val/${f}@0" || reached ? "val/*@0") (attrNames opaqueAt));
          # .42: the seal binds a verdict to the engine, the rules and the facts it was computed from. Anything else that
          # changes a verdict changes one of them. Checking a seal is evaluating again: `verify` answers { ok; why; }
          hash = x: b.hashString "sha256" (b.toJSON x);
          binding = {
            engine = hash (
              map (f: b.hashFile "sha256" f) [
                ./default.nix
                ./lib/datalog.nix
              ]
            );
            rules = hash (map (x: x.r) checked);
            facts = hash facts;
          };
          refuse = why: {
            ok = false;
            inherit why;
          };
          verify =
            s:
            if s.binding.engine != binding.engine then
              refuse "engine"
            else if s.binding.rules != binding.rules then
              refuse "rules"
            else if s.binding.facts != binding.facts then
              refuse "facts"
            else if !(D.checkCertificate verdictProgram s.certificate).valid then
              refuse "certificate"
            else if s.violations != violations || s.incomplete != incomplete then
              refuse "verdict"
            else
              { ok = true; };
          # .43: where a fact comes from, beside the fact, never in it: an edge's origin, or the files that declare its
          # instance, its field, or its aspect
          from =
            a:
            let
              r = head a;
              # the scope id: [ "kind" K ID ], [ "val" F ID V ] and [ "ref" F ID K N ] hold it second; the others first
              s = byId.${b.elemAt a (if elem r (words "kind val ref") then 2 else 1)} or null;
              inst =
                path:
                if s == null then
                  [ ]
                else
                  declaredIn (
                    [
                      s.kind
                      s.name
                    ]
                    ++ path
                  );
            in
            if r == "edge" then
              map (e: e.origin) (
                filter (
                  e:
                  [
                    "edge"
                    e.sink
                    e.from
                    e.to
                  ] == a
                ) graph.edges
              )
            else if r == "has" then
              filesOf (b.elemAt a 1)
            else if r == "val" || r == "ref" then
              inst [ (b.elemAt a 1) ]
            else if r == "error" then
              [ (b.elemAt a 2) ]
            else
              inst [ ];
          program = ground ++ D.facts facts;
          # the verdict's model plus the facts no rule body reads: they change no other atom, so it is the model of `program`
          model = m // {
            true = m.true ++ filter (a: !(mentioned ? ${key a})) facts;
          };
        in
        {
          inherit
            violations
            incomplete
            errors
            certificate
            certified
            verify
            from
            opaque
            ;
          seal = static.jsonSafe {
            inherit
              binding
              certificate
              violations
              incomplete
              ;
          };
          ok = violations == [ ] && incomplete == [ ] && opaque == [ ];
          why = D.why program model;
          whyNot = D.whyNot program model;
          proof = D.proof program model;
          invariants = attrNames invs;
        };
      lib =
        tools
        // genAttrs combinators (
          c: p: {
            "__${c}" = p;
            __functor = self: holds self;
          }
        )
        // {
          inherit
            holds
            graph
            declaredIn
            labels
            floor
            schema
            ; # queries readable inside the fleet (docs); `check` and `context` read errors, so not here
          same = x: y: isRef x && isRef y && x.kind == y.kind && x.name == y.name; # total: a non-instance is never the same
          nearest = k: nearest k.__kind;
          scopesOf = x: filter (s: s.kind == x.kind && s.name == x.name) scopes;
          children = p: s: filter (holds p) (childrenAt.${s.id} or [ ]); # the children of a scope where p holds, sorted
          cascade = path: foldl' (a: x: if a != null then a else (get path x).ok or null) null; # first answer along a list of scopes
        };
      # ── schema: what a fleet declares, as JSON-safe data (no functions): for agents and docs ──
      fieldsOf =
        t:
        if isType t then
          {
            type = typeName t;
          }
          // (if refKind t != null then { ref = refKind t; } else { })
          // (
            if t ? default && elem (b.typeOf t.default) (words "string int bool null list") then
              { default = t.default; }
            else
              { }
          )
          // (if t ? defaultFrom then { derived = true; } else { })
        else if isAttrs t then
          mapAttrs (_: fieldsOf) t
        else
          { type = b.typeOf t; };
      sinkSchema =
        v:
        let
          d = if isAttrs v then v else { };
        in
        {
          reduce = if d ? reduce then d.reduce.name or "custom" else "list";
          of = if d ? of then typeName d.of else null;
          feeds = attrNames (removeAttrs d sinkMeta);
          conditional = d ? at;
        };
      schema = {
        kinds = mapAttrs (k: d: {
          fields = fieldsOf (d.fields or { });
          spawns = attrNames (d.spawns or { });
          sinks = mapAttrs (_: sinkSchema) (d.sinks or { });
          instances = length (instNames k);
          scopes = length (filter (s: s.kind == k) scopes);
        }) (top.kinds or { });
        aspects = mapAttrs (n: a: {
          keys = attrNames (removeAttrs a (words "at order __aspect"));
          cycle = a ? cycle;
          files = filesOf n;
          activeAt = length (filter (s: active.${n}.${s.id}) unsorted);
        }) aspects;
        invariants = attrNames yen.invariants;
        queries = words "errors graph scopes active reduced undefined declaredIn facts check schema flake";
      };
      # ── explain: why an aspect is (not) active at a scope, as a three-valued trace of its `at`, cut at a depth ──
      byId = byScope (s: s) unsorted;
      noScope = from: id: unknown from id (attrNames byId) { code = "unknown-scope"; };
      trace =
        d: p: s:
        let
          v = eval3 [ ] p s;
          node =
            op: x:
            {
              inherit op;
              value = v;
            }
            // x;
          kids = f: if d == 0 then "cut" else f (d - 1);
          sub = ps: { kids = kids (d': map (q: trace d' q s) ps); }; # the same scope
          at = ss: q: { kids = kids (d': map (x: { scope = x.id; } // trace d' q x) ss); }; # other scopes
        in
        if isFunction p then
          node "function" { }
        else if isList p then
          node "any" (sub p)
        else if p ? __all then
          node "all" (sub p.__all)
        else if p ? __not then
          node "not" (sub [ p.__not ])
        else if p ? __within then
          node "within" (at (above s) p.__within)
        else if p ? __has then
          node "has" (at (below s) p.__has)
        else if p ? __functor then
          node "function" { }
        else if p ? __kind then
          node "kind" { kind = p.__kind; }
        else if p ? __aspect then
          node "aspect" ({ aspect = p.__aspect; } // sub [ (aspects.${p.__aspect}.at or [ ]) ])
        else
          node "instance" { instance = "${p.kind or "?"}:${p.name or "?"}"; };
      explain =
        n: id: depth:
        let
          s = byId.${id};
          v = s.__here.${n};
        in
        if !(aspects ? ${n}) then
          unknown "explain" n aspectNames { code = "unknown-aspect"; }
        else if !(byId ? ${id}) then
          noScope "explain" id
        else
          {
            aspect = n;
            scope = id;
            active = if v == null then "undefined" else v;
            at = trace depth (aspects.${n}.at or [ ]) s;
            gives = map (e: { inherit (e) sink to; }) (
              filter (e: e.origin == "aspect ${n}" && e.from == id) graph.edges
            );
            files = filesOf n;
          };
      # ── the agent surface: JSON-safe answers, every list says when it was cut ──
      cut =
        max: xs:
        let
          shown = if length xs < max then length xs else max;
        in
        {
          items = b.genList (b.elemAt xs) shown;
          truncated = {
            inherit shown;
            of = length xs;
          };
        };
      context =
        id:
        {
          maxEdges ? 20,
          maxAspects ? 50,
        }:
        let
          s = byId.${id};
        in
        if !(byId ? ${id}) then
          noScope "context" id
        else
          static.jsonSafe {
            scope = id;
            inherit (s) kind name;
            parent = if s.parent == null then null else s.parent.id;
            children = map (c: c.id) (below s);
            aspects = cut maxAspects (filter (n: active.${n}.${id}) aspectNames);
            undefined = map (x: x.aspect) (filter (x: x.scope == id) undefined);
            given = cut maxEdges (filter (e: e.from == id) graph.edges);
            received = cut maxEdges (filter (e: e.to == id) graph.edges);
            errors = filter (e: e.from == id) errorsAll;
          };
      agent = static.jsonSafe {
        inherit schema undefined;
        errors = errorsAll;
        check = { inherit (check) violations incomplete ok; };
        counts = {
          scopes = length scopes;
          edges = length graph.edges;
          aspects = length aspectNames;
          kinds = length kindNames;
        };
      };
      # ── impact: the scopes an element of `id` reaches, transitively over routed elements, by depth ──
      impact =
        id:
        {
          hops ? 3,
          sinks ? null,
          max ? 50,
        }:
        let
          bad = if sinks == null then [ ] else filter (k: !elem k sinkNames) sinks;
          step = from: filter (e: e.from == from && (sinks == null || elem e.sink sinks)) graph.edges;
          reached = genericClosure {
            startSet = [
              {
                key = id;
                depth = 0;
              }
            ];
            operator =
              x:
              if x.depth >= hops then
                [ ]
              else
                map (e: {
                  key = e.to;
                  depth = x.depth + 1;
                  via = e.sink;
                }) (step x.key);
          };
          c = cut max (
            map
              (x: {
                scope = x.key;
                inherit (x) depth via;
              })
              (
                b.sort (p: q: p.depth < q.depth || p.depth == q.depth && p.key < q.key) (
                  filter (x: x.key != id) reached
                )
              )
          );
        in
        if !(byId ? ${id}) then
          noScope "impact" id
        else if bad != [ ] then
          unknown "impact" (head bad) sinkNames { code = "unknown-sink"; }
        else
          {
            reached = c.items;
            inherit (c) truncated;
            inherit hops;
          };
      # ── labels by file path prefix (`yen.labels."agent/" = { trust = 1; }`): an aspect's label is the meet (the
      # lowest trust) over the files that declare it; an element carries its aspect's label; `floor n` lists what is below.
      # A prefix is literal text after a `/`, never a regex. When the fleet has labels, an aspect no prefix covers has
      # trust 0: unknown provenance is never above a floor ──
      labelTable = top.labels or { };
      unlabeled = {
        trust = 0;
        prefix = null;
        file = null;
      };
      labelOf =
        n:
        foldl' (a: x: if a == null || (x.trust or 0) < (a.trust or 0) then x else a) null (
          concatMap (
            f:
            map (
              p:
              labelTable.${p}
              // {
                prefix = p;
                file = f;
              }
            ) (filter (p: hasInfix "/${p}" f) (attrNames labelTable))
          ) (filesOf n)
        );
      labels =
        if labelTable == { } then
          { }
        else
          mapAttrs (n: _: if labelOf n == null then unlabeled else labelOf n) aspects;
      floor = floorOf labels graph.edges;
      # a key yen does not read is an error, not a silent no-op: yen modules are not NixOS modules.
      # `from` is the module that declares the key
      keyErrors =
        let
          bad =
            from: path: known: xs:
            map (
              k:
              errWith (from k) "`${k}` is not a key yen reads here" {
                code = "unknown-key";
                path = path ++ [ k ];
                near = near k known;
                want = known;
                fix = "use one of the keys in `want`; yen modules are not NixOS modules";
              }
            ) (filter (k: !elem k known) xs);
          files = path: k: concatStringsSep ", " (declaredIn (path ++ [ k ]));
        in
        concatMap (n: bad (_: n.key) [ ] moduleKeys (if isAttrs n.mod then attrNames n.mod else [ ])) (
          filter (n: n ? mod) loaded
        )
        ++ bad (files [ ]) [ "yen" ] (yenKeys ++ kindNames) (attrNames top)
        ++ concatMap (
          k:
          bad (files [
            "kinds"
            k
          ]) [ "yen" "kinds" k ] kindKeys (attrNames top.kinds.${k})
        ) kindNames;
      # `scope` and `sinks` are fixed args: a sink of that name could never be read
      reservedErrors =
        map
          (
            n:
            errWith "declarations" "sink `${n}`: the name is a fixed arg" {
              code = "reserved";
              fix = "rename the sink; `scope` and `sinks` are args of every element";
            }
          )
          (
            filter (n: elem n sinkNames) [
              "scope"
              "sinks"
            ]
          )
        # a field named like a key of the scope record would read as that key, never as the field
        ++ concatMap (
          k:
          map (
            n:
            errWith "declarations" "field `${n}` of kind ${k}: the name is a key of every scope" {
              code = "reserved";
              path = [
                k
                n
              ];
              want = scopeKeys;
              fix = "rename the field; a scope already has ${concatStringsSep ", " scopeKeys}";
            }
          ) (filter (n: elem n scopeKeys) (attrNames (kinds.${k}.fields or { })))
        ) kindNames;
      # every error but the invariants': the `error` facts read these, so a rule never reads its own errors
      errorsFleet =
        loadErrors
        ++ reservedErrors
        ++ keyErrors
        ++ declErrors [ ]
        ++ concatMap (k: concatMap (n: (inst k n [ ]).errors) (instNames k)) kindNames
        ++ treeErrors
        ++ atErrors
        ++ orderErrors
        ++ requestErrors
        ++ reduceErrors
        ++ emitted
        ++ optional (!(flakeFill ? ok)) flakeFill
        ++ concatMap (x: if x ? error then [ x.error ] else [ ]) fieldAtoms;
      errorsAll = errorsFleet ++ check.errors;
      flakeFill = if top ? flake && scopes != [ ] then fill (head scopes) top.flake else { ok = null; };
      clean = errorsAll == [ ] && check.ok;
      self = {
        inherit
          scopes
          active
          graph
          undefined
          declaredIn
          check
          facts
          schema
          explain
          context
          agent
          impact
          labels
          floor
          ;
        inherit root; # the module this result came from: a stored query can stage a change against it
        # every instance's field values, JSON-safe: for history diffs and agents
        data = mapAttrs (
          k: _:
          mapAttrs (
            n: i:
            static.jsonSafe (
              mapAttrs (_: v: if isRef v then "${v.kind}:${v.name}" else v) (removeAttrs i (words "kind name"))
            )
          ) instances.${k}
        ) kinds;
        errors = errorsAll;
        # L0: a fleet with an error, a violation, an undefined invariant or a forged rule head gives no outputs, and no
        # reduced sink values to build them from by hand (D13)
        reduced = if clean then reduced else null;
        flake = if clean then flakeFill.ok else null;
        # stored queries: `yen.queries.<name> = { host, result, ... }: …`. `result` is this eval result; the other formals are the
        # query's parameters, required unless they have a default. `ask name args` never throws: a missing or unknown
        # parameter, or an unknown query, is an error record.
        queries = mapAttrs (
          n: f:
          let
            fa = functionArgs f;
            ps = filter (a: a != "result") (attrNames fa);
          in
          {
            required = filter (a: !fa.${a}) ps;
            optional = filter (a: fa.${a}) ps;
          }
        ) yen.queries;
        ask =
          n: args:
          if !(yen.queries ? ${n}) then
            unknown "ask" n (attrNames yen.queries) { code = "unknown-query"; }
          else
            let
              q = self.queries.${n};
              missing = filter (a: !(args ? ${a})) q.required;
              extra = filter (a: !elem a (q.required ++ q.optional)) (attrNames args);
            in
            if missing != [ ] then
              errWith "ask" "query ${n}: missing ${head missing}" {
                code = "missing-param";
                want = q.required;
                got = attrNames args;
              }
            else if extra != [ ] then
              errWith "ask" "query ${n}: unknown parameter ${head extra}" {
                code = "unknown-param";
                near = near (head extra) (q.required ++ q.optional);
              }
            else
              static.jsonSafe (yen.queries.${n} (args // { result = self; }));
      };
    in
    self;
  # grants that only narrow: a grant names scope ids and sinks (null: every sink). A scope id covers itself and the
  # scopes under it, by path segment (`host:web` covers `host:web/user:a`, never `host:webhook`). Two grants meet: a
  # scope stays when one covers the other (the deeper is kept), sinks intersect. There is no way to widen.
  covers = p: s: s == p || b.substring 0 (b.stringLength p + 1) s == "${p}/";
  grants = {
    grant =
      {
        scopes,
        sinks ? null,
      }:
      {
        inherit scopes sinks;
      };
    narrow = g: h: {
      scopes = uniq (
        concatMap (
          p:
          concatMap (
            q:
            if covers p q then
              [ q ]
            else if covers q p then
              [ p ]
            else
              [ ]
          ) h.scopes
        ) g.scopes
      );
      sinks =
        if g.sinks == null then
          h.sinks
        else if h.sinks == null then
          g.sinks
        else
          filter (x: elem x h.sinks) g.sinks;
    };
    allowed = g: e: any (p: covers p e.to) g.scopes && (g.sinks == null || elem e.sink g.sinks);
  };
  # data with no functions: it can be hashed, rendered as JSON and read back
  isData =
    v:
    if isList v then
      all isData v
    else if isAttrs v then
      !(v ? __functor) && all isData (b.attrValues v)
    else
      !isFunction v;
  # stage: an agent's change, in quarantine. Nothing changes; two evals compare. `ok` only when nothing new is wrong.
  stage =
    {
      base,
      change,
      rejected ? [ ],
      grant ? null,
      by ? null, # who submits it: { name; trust; }; the change's aspects carry this label (none: trust 0)
      id ? null, # the change's content hash, when the caller knows it (a program); else from a path or data
      baseResult ? eval base,
    }: # baseResult: the base already evaluated. The invariants always run: the law is not optional
    let
      changedResult = eval {
        imports = [
          base
          change
        ];
      };
      keyE = e: "${e.from}|${e.error}";
      keyG = e: "${e.sink}|${e.from}|${e.to}|${e.origin}";
      minus =
        k: xs: ys:
        let
          has = keySet (map k ys);
        in
        filter (x: !(has ? ${k x})) xs;
      delta = k: f: {
        added = minus k (f changedResult) (f baseResult);
        removed = minus k (f baseResult) (f changedResult);
      };
      ids = r: map (s: s.id) r.scopes;
      activeList =
        r:
        concatMap (n: map (id: "${n}@${id}") (filter (id: r.active.${n}.${id}) (attrNames r.active.${n}))) (
          attrNames r.active
        );
      sha =
        if id != null then
          id
        else if isPath change then
          b.hashFile "sha256" change
        else if isData change then
          b.hashString "sha256" (b.toJSON change)
        else
          null;
      diff = {
        scopes = delta (x: x) ids;
        edges = delta keyG (r: r.graph.edges);
        active = delta (x: x) activeList;
      };
      # what the change itself declares: no value comparison (reduced values can hold functions and cycles)
      declared = eval change;
      # D14-A: every module reads the whole fleet through `yen`, so a change that declares anything can reach every
      # scope and every sink. shortcut: sound but coarse; R-yen (yen-704.27) makes reads visible, then grants narrow again
      # .20 .13: every aspect the change declares carries its submitter's label, whatever file (or inline program op)
      # holds it, so a floor sees the agent
      labels =
        changedResult.labels
        //
          genAttrs
            (filter (
              n:
              declared.declaredIn [
                "aspects"
                n
              ] != [ ]
            ) (attrNames changedResult.active))
            (_: {
              trust = by.trust or 0;
              by = by.name or null;
              prefix = null;
              file = null;
            });
      reaches = any (k: declared.declaredIn [ k ] != [ ]) (
        yenKeys ++ attrNames changedResult.schema.kinds
      );
      outside =
        id:
        errWith "stage" "the change can reach ${id}, outside the grant" {
          code = "outside-grant";
          class = "authority";
          got = id;
        };
      lawKeys = words "invariants relations labels flake";
      law = filter (k: declared.declaredIn [ k ] != [ ]) lawKeys;
      errors = minus keyE changedResult.errors baseResult.errors;
      violations = filter (a: !elem a baseResult.check.violations) changedResult.check.violations;
      incomplete = filter (a: !elem a baseResult.check.incomplete) changedResult.check.incomplete;
      refused =
        optional (sha != null && elem sha rejected) (
          errWith "stage" "this change was rejected before" {
            code = "rejected";
            class = "authority";
            got = sha;
          }
        )
        ++ map (
          k:
          errWith "stage" "the change declares `${k}`: the law is the owner's, never a change's" {
            code = "law-change";
            class = "authority";
            path = [ k ];
          }
        ) law
        # one refusal per scope, before or after the change, that the grant does not cover for every sink
        ++ map outside (
          filter (
            id:
            grant != null
            && reaches
            && !grants.allowed grant {
              to = id;
              sink = null;
            }
          ) (attrNames (keySet (ids baseResult ++ ids changedResult)))
        );
    in
    {
      inherit
        errors
        refused
        sha
        violations
        incomplete
        diff
        labels
        ;
      floor = floorOf labels changedResult.graph.edges;
      ok = errors == [ ] && violations == [ ] && incomplete == [ ] && refused == [ ];
      render = if isData change then b.toJSON change else null; # read back with builtins.fromJSON
    };
  # field changes between two `data` answers: [ { path; old; new; } ], sorted by path
  diffData =
    d0: d1:
    let
      keys = a: c: names (attrNames a ++ attrNames c);
      go =
        p: x: y:
        if isAttrs x && isAttrs y then
          concatMap (k: go (p ++ [ k ]) (x.${k} or null) (y.${k} or null)) (keys x y)
        else if x == y then
          [ ]
        else
          [
            {
              path = p;
              old = x;
              new = y;
            }
          ];
    in
    go [ ] d0 d1;
  # the fleet at a git revision (transaction time): `module` is the fleet module path inside the repository
  asOf =
    {
      url,
      rev,
      module,
    }:
    eval (import ((b.fetchGit { inherit url rev; }) + "/${module}"));
  history =
    {
      url,
      revs,
      module,
    }:
    let
      r = b.elemAt (map (rev: asOf { inherit url rev module; }) revs); # one eval per revision
    in
    b.genList (i: {
      rev = b.elemAt revs i;
      errors = length (r i).errors;
      scopes = length (r i).scopes;
      changes = if i == 0 then [ ] else diffData (r (i - 1)).data (r i).data;
    }) (length revs);
  # without: the fleet with the files that declare `path` removed (coarse: a whole file goes; no engine hook)
  without =
    {
      files,
      path,
      args ? { },
    }:
    let
      mk = fs: {
        imports = fs;
        _module.args = args;
      };
      hit = (eval (mk files)).declaredIn path;
      keep = filter (f: !elem (toString f) hit) files;
    in
    {
      dropped = filter (f: elem (toString f) hit) files;
      result = eval (mk keep);
    };
  # change programs: a change as a list of data ops, so an agent can write, check, show and replay it.
  #   { op = "set"; path; value; }          one declaration path gets a value
  #   { op = "ref"; path; kind; name; }     one declaration path gets an instance ref
  #   { op = "place"; aspect; kind; name; } the aspect is also active at that instance
  #   { op = "new"; kind; name; fields; }   a new instance (a field value { ref = { kind; name; }; } is a ref)
  program = rec {
    opErrors =
      r: i: o:
      let
        kinds = r.schema.kinds;
        k = head o.path;
        f = b.elemAt o.path 2;
        fs = attrNames (kinds.${k}.fields or { });
        fail = msg: x: [ (errWith "program[${toString i}]" msg ({ code = "program"; } // x)) ];
        noKind = if kinds ? ${o.kind or ""} then [ ] else fail "no kind ${o.kind or "?"}" { };
      in
      if !isAttrs o || !(o ? op) then
        fail "not an op" { want = "{ op = …; }"; }
      else if o.op == "set" || o.op == "ref" then
        if !(isList (o.path or null)) || o.path == [ ] then
          fail "path must be a non-empty list" { }
        else if !(kinds ? ${k}) then
          fail "no kind ${k}" { near = near k (attrNames kinds); }
        else if length o.path > 2 && !elem f fs then
          fail "kind ${k} has no field ${f}" { near = near f fs; }
        else if o.op == "ref" then
          noKind
        else
          [ ]
      else if o.op == "place" then
        if r.schema.aspects ? ${o.aspect or ""} then
          [ ]
        else
          fail "no aspect ${o.aspect or "?"}" { near = near (o.aspect or "") (attrNames r.schema.aspects); }
      else if o.op == "new" then
        noKind
      else
        fail "unknown op ${toString o.op}" {
          near = near (toString o.op) (words "set ref place new");
        };
    validate = r: prog: b.concatLists (b.genList (i: opErrors r i (b.elemAt prog i)) (length prog));
    # the program as one yen module (a function: refs need `yen`)
    toModule =
      prog:
      { yen, ... }:
      let
        refOf = x: if isAttrs x && x ? ref then yen.${x.ref.kind}.${x.ref.name} else x;
        one =
          o:
          if o.op == "set" then
            nest o.path o.value
          else if o.op == "ref" then
            nest o.path yen.${o.kind}.${o.name}
          else if o.op == "place" then
            { aspects.${o.aspect}.at = [ { inherit (o) kind name; } ]; }
          else
            { ${o.kind}.${o.name} = mapAttrs (_: refOf) (o.fields or { }); };
      in
      {
        imports = map (o: { yen = one o; }) prog;
      };
    dryRun =
      {
        base,
        prog,
        grant ? null,
        rejected ? [ ],
        by ? null,
        result ? eval base,
      }:
      let
        errs = validate result prog;
        s = stage {
          inherit
            base
            grant
            rejected
            by
            ;
          baseResult = result;
          change = toModule prog;
          id = b.hashString "sha256" (b.toJSON prog); # a program is data: `rejected` matches it
        };
      in
      if errs != [ ] then
        {
          ok = false;
          valid = false;
          errors = errs;
        }
      else
        removeAttrs s [ "render" ] // { valid = true; };
    render = b.toJSON;
  };
  # a change as data: set one declaration path (`change.set [ "host" "web-1" "port" ] 8080`)
  change = {
    set = path: value: { yen = nest path value; };
  };
  # agent tools: the engine library outside an eval, and inside the fleet too
  tools = static // {
    inherit
      stage
      change
      program
      grants
      diffData
      without
      ;
    inherit (grants) grant narrow allowed;
  };
in
{
  lib = tools // {
    inherit eval asOf history;
    mkFlake = m: (eval m).flake;
  };
}
