# sven.nix: builtins only. A query language for configurations: a Cycle.js loop over nested scopes.
# No throws: an error is an emission. No merge, no module system: every read is a query on the files that answer it.
# Entry: `(import ./sven.nix).lib.eval module`. A module is a path, a function or an attrset; `imports` nest, `_module.args` flow down.
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
    ;

  # ── tiny helpers (no nixpkgs) ──
  toList = v: if isList v then v else [ v ];
  reverse = xs: b.genList (i: b.elemAt xs (length xs - 1 - i)) (length xs);
  first =
    p: xs:
    foldl' (
      a: x:
      if a != null then
        a
      else if p x then
        x
      else
        null
    ) null xs;
  uniq = foldl' (acc: x: if elem x acc then acc else acc ++ [ x ]) [ ];
  names =
    xs:
    attrNames (
      listToAttrs (
        map (n: {
          name = n;
          value = null;
        }) xs
      )
    );
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
  # edit distance (Levenshtein), for `near`: the known names a typo was probably meant to be
  dist =
    a: c:
    let
      n = b.stringLength c;
      ch = s: i: b.substring i 1 s;
      min = x: y: if x < y then x else y;
      row =
        prev: i:
        foldl' (
          r: j:
          r
          ++ [
            (b.foldl' min (b.elemAt prev (j + 1) + 1) [
              (b.elemAt r j + 1)
              (b.elemAt prev j + (if ch a i == ch c j then 0 else 1))
            ])
          ]
        ) [ (i + 1) ] (b.genList (j: j) n);
    in
    b.elemAt (foldl' row (b.genList (j: j) (n + 1)) (b.genList (i: i) (b.stringLength a))) n;
  near =
    x: cs:
    map (p: p.c) (
      b.sort (p: q: p.d < q.d || p.d == q.d && p.c < q.c) (
        b.filter (p: p.d <= 2 && p.d < b.stringLength x) (
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
  checkOf = t: if t ? __kind then (v: isAttrs v && (v.kind or null) == t.__kind) else t.check;
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
      common = filter (n: a ? ${n}) (attrNames bv);
      sub =
        n:
        if isLeaf a.${n} || isLeaf bv.${n} then
          {
            value = a.${n};
            errors =
              if a.${n} == bv.${n} then
                [ ]
              else
                [
                  (errWith "merge" "merge conflict at ${concatStringsSep "." (path ++ [ n ])}" {
                    code = "merge";
                    path = path ++ [ n ];
                  })
                ];
          }
        else
          mergeAt (path ++ [ n ]) a.${n} bv.${n};
    in
    {
      value = a // mapAttrs (n: v: if a ? ${n} then (sub n).value else v) bv;
      errors = concatMap (n: (sub n).errors) common;
    };
  reduce = {
    list = es: {
      value = map (e: e.value) es;
      errors = [ ];
    };
    set = es: {
      value = uniq (map (e: e.value) es);
      errors = [ ];
    };
    one = es: {
      value = if es == [ ] then null else (head es).value;
      errors =
        if length es == 1 then
          [ ]
        else
          [
            (errWith "one" "one: got ${toString (length es)} elements" {
              code = "one";
              got = length es;
              want = 1;
            })
          ];
    };
    merge =
      es:
      foldl'
        (
          acc: e:
          let
            m = mergeAt [ ] acc.value e.value;
          in
          {
            value = m.value;
            errors = acc.errors ++ m.errors;
          }
        )
        {
          value = { };
          errors = [ ];
        }
        es;
    entries = es: {
      value = es;
      errors = [ ];
    };
  };
  # each built-in reduce is callable and carries its name, so `schema` can say which strategy a sink uses
  reduceNamed = mapAttrs (n: f: {
    __functor = _: f;
    name = n;
  }) reduce;
  static = {
    reduce = reduceNamed;
    is = check: { inherit check; }; # any check is a type: `sven.lib.is builtins.isString`
    opt = t: d: t // { default = d; };
    derive = t: f: t // { defaultFrom = f; }; # a default computed from the instance itself (Den schema defaults)
    maybe = t: {
      check = v: v == null || checkOf t v;
      default = null;
    };
    graphs = import ./lib/graphs.nix; # reach, transpose, topo, layers, sccs, cycles, paths, shortest over succ attrsets
    rdf = import ./lib/rdf.nix; # triples, ntriples, share: an eval result as sorted N-Triples with a content hash
    datalog = import ./lib/datalog.nix; # ground rules with negation: wfs (three values), stable, why
    # JSON-safe: functions and derivations become strings; toJSON then never fails
    jsonSafe =
      v:
      if b.isFunction v then
        "<function>"
      else if b.isPath v then
        toString v
      else if b.isList v then
        map static.jsonSafe v
      else if b.isAttrs v then
        (
          if (v.type or null) == "derivation" then
            "<derivation ${v.name or "?"}>"
          else if v ? __functor then
            "<function>"
          else
            b.mapAttrs (_: static.jsonSafe) v
        )
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
              args = args // (v._module.args or { }) // { inherit sven; };
            }
        );
      loaded = genericClosure {
        startSet = [ (node { inherit sven; } "root" root) ];
        operator =
          n:
          let
            imps = n.mod.imports or [ ];
          in
          if n ? mod then
            b.genList (i: node n.args "${n.key}/${toString i}" (b.elemAt imps i)) (length imps)
          else
            [ ];
      };
      defs = map (n: n.mod.sven or { }) (filter (n: n ? mod) loaded);
      # the modules (file paths, or positions for inline modules) that answer a declaration path, in file order
      declaredIn =
        path:
        map (n: n.key) (
          filter (
            n:
            n ? mod
            &&
              (foldl' (a: k: if a != null && isAttrs a && a ? ${k} then a.${k} else null) (n.mod.sven or { }
              ) path) != null
          ) loaded
        );
      loadErrors = map (n: err "module" n.error) (filter (n: n ? error) loaded);

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
          listToAttrs (
            map (n: {
              name = n;
              value = decl (path ++ [ n ]);
            }) (names (attrsIn hs))
          )
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
      kindNames = attrNames (top.kinds or { });
      aspectNames = attrNames (top.aspects or { });
      kinds = listToAttrs (
        map (k: {
          name = k;
          value = top.kinds.${k} // {
            __kind = k;
            check = v: isAttrs v && (v.kind or null) == k;
          };
        }) kindNames
      ); # a kind is a type: its instances pass
      aspects = listToAttrs (
        map (n: {
          name = n;
          value = top.aspects.${n} // {
            __aspect = n;
          };
        }) aspectNames
      );

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
      dataAt =
        k: n: path:
        let
          hits = answers (
            [
              k
              n
            ]
            ++ path
          );
          d = first (t: isAttrs t && (t ? default || t ? defaultFrom)) (typesAt k path);
        in
        if hits != [ ] then
          { ok = head hits; }
        else if d != null then
          { ok = if d ? defaultFrom then d.defaultFrom instances.${k}.${n} else d.default; }
        else
          { };
      view =
        k: n: path:
        let
          ts = typesAt k path;
          tys = filter isType ts;
          r = dataAt k n path;
        in
        if tys != [ ] then
          (if r ? ok && all (t: checkOf t r.ok) tys then r.ok else null)
        else if path != [ ] && ts == [ ] then
          null
        else
          listToAttrs (
            map
              (f: {
                name = f;
                value = view k n (path ++ [ f ]);
              })
              (
                names (
                  attrsIn (
                    answers (
                      [
                        k
                        n
                      ]
                      ++ path
                    )
                    ++ ts
                  )
                )
              )
          );
      instErrors =
        k: n: path:
        let
          ts = typesAt k path;
          tys = filter isType ts;
          r = dataAt k n path;
          id = "${k}:${n}";
          p = concatStringsSep "." path;
        in
        if tys != [ ] then
          (
            if !(r ? ok) then
              [
                (errWith id "missing ${p}" {
                  code = "missing";
                  inherit path;
                  want = typeName (head tys);
                  fix = "set ${id}.${p}";
                })
              ]
            else if all (t: checkOf t r.ok) tys then
              [ ]
            else
              [
                (
                  let
                    bad = first (t: !checkOf t r.ok) tys;
                    kr = first (t: t ? __kind) tys;
                  in
                  errWith id (if kr != null then "${p} wants a ${kr.__kind} ref" else "${p} fails its check") {
                    code = if kr != null then "ref" else "check";
                    inherit path;
                    got = if isFunction r.ok then "<function>" else r.ok;
                    want = typeName bad;
                    fix =
                      if kr != null then
                        "use sven.${kr.__kind}.<name>, not a string"
                      else
                        "give ${p} a value of type ${typeName bad}";
                  }
                )
              ]
          )
        else if path != [ ] && ts == [ ] then
          [
            (
              let
                known = (attrsIn (typesAt k (b.genList (i: b.elemAt path i) (length path - 1))));
              in
              errWith id "unknown field ${p}" {
                code = "unknown-field";
                inherit path;
                near = near (b.elemAt path (length path - 1)) (names known);
                fix = "declare sven.kinds.${k}.fields.${p}, or use a declared field";
              }
            )
          ]
        else
          concatMap (f: instErrors k n (path ++ [ f ])) (
            names (
              attrsIn (
                answers (
                  [
                    k
                    n
                  ]
                  ++ path
                )
                ++ ts
              )
            )
          );
      instNames = k: attrNames (top.${k} or { });
      instances = mapAttrs (
        k: _:
        listToAttrs (
          map (n: {
            name = n;
            value = view k n [ ] // {
              kind = k;
              name = n;
            };
          }) (instNames k)
        )
      ) kinds;
      sven = instances // {
        inherit kinds aspects lib;
        helpers = top.helpers or { };
        queries = top.queries or { };
        invariants = top.invariants or { };
        labelTable = top.labels or { };
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
            [ (err s.id "spawns.${c} gives no attrset") ]
          else
            map (
              n:
              if any (x: x.key == "${c}:${n}") s.up then
                errWith s.id "instance ${c}:${n} twice on path" {
                  code = "cycle";
                  got = "${c}:${n}";
                }
              else if !isAttrs made.${n} then
                err s.id "spawns.${c}.${n} is no attrset"
              else
                mkScope s c n made.${n}
            ) (attrNames made)
        ) (attrNames (spawnsOf s.kind));
      tree = genericClosure {
        # C-level loop, breadth first: a parent comes before its children
        startSet = map (s: {
          key = s.id;
          inherit s;
        }) roots;
        operator =
          i:
          if i ? s then
            map (
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
                }
            ) (childrenOf i.s)
          else
            [ ];
      };
      unsorted = map (i: i.s) (filter (i: i ? s) tree);
      treeErrors = map (i: i.e) (filter (i: i ? e) tree);
      byParent = groupBy (s: if s.parent == null then "" else s.parent.id) unsorted;

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
        else if p ? __all then
          concatMap refsOf p.__all
        else if p ? __not then
          refsOf p.__not
        else if p ? __within then
          refsOf p.__within
        else if p ? __has then
          refsOf p.__has
        else if p ? __aspect then
          [ p.__aspect ]
        else
          [ ];
      reach = mapAttrs (
        n: a:
        map (x: x.key) (genericClosure {
          startSet = map (r: { key = r; }) (refsOf (a.at or [ ]));
          operator = x: map (r: { key = r; }) (refsOf (aspects.${x.key}.at or [ ]));
        })
      ) aspects;
      cyclic = mapAttrs (n: rs: elem n rs) reach;
      tainted = mapAttrs (n: rs: cyclic.${n} || any (r: cyclic.${r}) rs) reach; # can be undefined: it reaches a cycle
      or3 =
        vs:
        if any (v: v == true) vs then
          true
        else if any (v: v == null) vs then
          null
        else
          false;
      and3 =
        vs:
        if any (v: v == false) vs then
          false
        else if any (v: v == null) vs then
          null
        else
          true;
      eval3 =
        stack: p: s:
        if isFunction p then
          p s
        else if isList p then
          (if length p == 1 then eval3 stack (head p) s else or3 (map (q: eval3 stack q s) p)) # `at` is always a list (a union over files): one entry is the common case
        else if isAttrs p && p ? __all then
          and3 (map (q: eval3 stack q s) p.__all)
        else if isAttrs p && p ? __not then
          (
            let
              v = eval3 (map (x: x // { neg = true; }) stack) p.__not s;
            in
            if v == null then null else !v
          )
        else if isAttrs p && p ? __within then
          or3 (map (eval3 stack p.__within) (above s))
        else if isAttrs p && p ? __has then
          or3 (map (eval3 stack p.__has) (byParent.${s.id} or [ ]))
        else if isFunction p || p ? __functor then
          p s
        else if p ? __kind then
          s.kind == p.__kind
        else if p ? __aspect then
          let
            q = p.__aspect;
            key = "${q}@${s.id}";
            hit = first (x: x.key == key) stack;
          in
          if hit != null then
            (if hit.neg then null else false)
          else if stack == [ ] || !cyclic.${q} then
            s.__here.${q} # per scope: structure may depend on presence (Den #525) without the whole tree
          else
            eval3 (
              stack
              ++ [
                {
                  inherit key;
                  neg = false;
                }
              ]
            ) (aspects.${q}.at or [ ]) s
        else
          p ? kind && p ? name && s.kind == p.kind && s.name == p.name;
      here =
        s:
        mapAttrs (
          q: a:
          eval3 [
            {
              key = "${q}@${s.id}";
              neg = false;
            }
          ] (a.at or [ ]) s
        ) aspects;
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
      inRefs = listToAttrs (
        map (n: {
          name = n;
          value = true;
        }) (concatMap (n: if reach.${n} == [ ] then [ ] else [ n ] ++ reach.${n}) aspectNames)
      );
      active = mapAttrs (
        n: a:
        let
          at = if inRefs ? ${n} then (s: s.__here.${n} == true) else holds (a.at or [ ]);
        in
        listToAttrs (
          map (s: {
            name = s.id;
            value = at s;
          }) unsorted
        )
      ) aspects;
      undefined = concatMap (
        s:
        map (n: {
          aspect = n;
          scope = s.id;
        }) (filter (n: s.__here.${n} == null) (filter (n: tainted.${n}) aspectNames))
      ) unsorted;
      atErrors = concatMap (
        n:
        map
          (
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
          ) # a typo must not read as false
          (
            filter (
              p:
              !(
                isFunction p
                || isList p
                || isAttrs p && (p ? __functor || p ? __kind || p ? __aspect || p ? kind && p ? name)
              )
            ) (toList (aspects.${n}.at or [ ]))
          )
      ) aspectNames;

      # ── components: one cycle per (aspect, scope). Its own tree requests feed its sources ──
      cycleOuts = mapAttrs (
        n: a:
        listToAttrs (
          map (s: {
            name = s.id;
            value =
              let
                o = a.cycle (sourcesAt s (o.tree or [ ]));
              in
              o;
          }) (filter (s: active.${n}.${s.id}) unsorted)
        )
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
      orderOf =
        s:
        let
          os = filter (o: b.isInt o || b.isFloat o) (ordersAt s);
        in
        if os == [ ] then 0 else head os;
      orderErrors = concatMap (
        s:
        if all (o: b.isInt o || b.isFloat o) (ordersAt s) then
          [ ]
        else
          [ (err s.id "order is not a number") ]
      ) unsorted;
      sortKeys = listToAttrs (
        map (s: {
          name = s.id;
          value = (if s.parent == null then [ ] else sortKeys.${s.parent.id}) ++ [
            [
              (orderOf s)
              s.key
            ]
          ];
        }) unsorted
      );
      scopes =
        b.seq (foldl' (_: s: sortKeys.${s.id}) null unsorted) # force keys breadth first: no deep thunk chain
          (b.sort (x: y: sortKeys.${x.id} < sortKeys.${y.id}) unsorted);
      childrenAt = groupBy (s: if s.parent == null then "" else s.parent.id) scopes;

      # ── routing: nearest ancestor-or-self receiver (Cycle isolateSink tags the identity) ──
      sinkOf = s: k: (kinds.${s.kind}.sinks or { }).${k} or null;
      sinkKeys =
        d:
        filter (
          k:
          !elem k [
            "at"
            "reduce"
            "of"
          ]
        ) (attrNames d);
      sinkNames = uniq (concatMap (k: attrNames (k.sinks or { })) (b.attrValues kinds));
      nearestFirst = s: s.rup;
      above = s: if s.parent == null then [ ] else reverse s.parent.up;
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
            concatMap
              (
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
              )
              (
                filter (
                  k:
                  !elem k [
                    "at"
                    "cycle"
                    "order"
                    "__aspect"
                  ]
                ) (attrNames a)
              )
            ++
              concatMap
                (
                  k:
                  let
                    vs = toList o.${k};
                  in
                  b.genList (i: {
                    origin = "aspect ${n}";
                    key = k;
                    from = s;
                    value = b.elemAt vs i;
                    raw = i;
                  }) (length vs)
                ) # raw = position: a cycle may emit many
                (
                  filter (
                    k:
                    !elem k [
                      "tree"
                      "order"
                    ]
                  ) (attrNames o)
                )
        ) aspectNames
      ) scopes;
      direct = concatMap (
        e:
        let
          to = receiverIn e.key (nearestFirst e.from);
        in
        if to == null then [ ] else [ (e // { inherit to; }) ]
      ) (filter (e: e.key != "errors") given); # nobody reads it: nothing happens
      fired = genericClosure {
        # which (sink, receiver) pairs fire: existence only
        startSet = map (e: {
          key = "${e.key}@${e.to.id}";
          sink = e.key;
          r = e.to;
        }) direct;
        operator =
          f:
          concatMap (
            k:
            let
              t = receiverIn k (if k == f.sink then above f.r else nearestFirst f.r);
            in
            if t == null then
              [ ]
            else
              [
                {
                  key = "${k}@${t.id}";
                  sink = k;
                  r = t;
                }
              ]
          ) (sinkKeys (sinkOf f.r f.sink));
      };
      fromSinks = concatMap (
        f:
        let
          d = sinkOf f.r f.sink;
        in
        concatMap (
          k:
          let
            to = receiverIn k (if k == f.sink then above f.r else nearestFirst f.r);
          in
          if to == null then
            [ ]
          else
            [
              {
                origin = "sink ${f.sink}";
                key = k;
                from = f.r;
                inherit to;
                value = d.${k};
              }
            ]
        ) (sinkKeys d)
      ) fired;
      routed = direct ++ fromSinks;
      byTo = groupBy (e: "${e.key}@${e.to.id}") routed;

      # ── sources at a scope (Cycle isolateSource): the tree driver and one source per sink ──
      isRen = n: n == "scope" || n == "tree" || kinds ? ${n} || elem n sinkNames;
      nearest = k: s: first (x: x.kind == k) (nearestFirst s);
      answer =
        s: q:
        if q ? nearest then
          (
            let
              x = nearest q.nearest.__kind s;
            in
            if x == null then err s.id "no ${q.nearest.__kind} above" else { ok = x; }
          )
        else if q ? parent then
          (if s.parent == null then err s.id "no parent" else { ok = s.parent; })
        else if q ? children then
          { ok = filter (holds q.children) (childrenAt.${s.id} or [ ]); }
        else if q ? scopesOf then
          { ok = filter (x: x.kind == q.scopesOf.kind && x.name == q.scopesOf.name) scopes; }
        else if q ? holds then
          { ok = holds q.holds s; }
        else
          err s.id "unknown tree request";
      sourcesAt =
        s: requests:
        {
          scope = s;
          tree.select =
            c:
            concatMap (
              q:
              let
                r = answer s q;
              in
              if q.category or null == c && r ? ok then [ r.ok ] else [ ]
            ) requests;
        }
        // listToAttrs (
          map (n: {
            name = n;
            value =
              let
                r = receiverIn n (nearestFirst s);
              in
              if r == null then [ ] else [ (memo.${n}.${r.id} or (reduceAt n r)).value ];
          }) sinkNames
        ); # a receiver with no element yet reduces to its empty value
      requestErrors = concatMap (
        s:
        concatMap (
          n:
          map (_: err s.id "aspect ${n}: unknown tree request") (
            filter (q: !(q ? nearest || q ? parent || q ? children || q ? scopesOf || q ? holds)) (
              toList ((outAt n s).tree or [ ])
            )
          )
        ) (attrNames cycleOuts)
      ) unsorted;

      # ── map: fill the args sven answers; other args stay open (`__functionArgs`) ──
      argAt =
        s: n:
        if n == "scope" then
          [ s ]
        else if kinds ? ${n} then
          (
            let
              x = nearest n s;
            in
            if x == null then [ ] else [ x ]
          )
        else
          (sourcesAt s [ ]).${n} or [ ];
      isAttrsFn = f: functionArgs f != { } || b.match ".*<attrspat.*" (b.toXML f) != null; # toXML only for `{ ... }:` vs `x:`
      fill =
        s: v:
        if !isFunction v then
          { ok = v; }
        else if !isAttrsFn v then
          errWith s.id "bare function: wrap it as `{ ... }:`" {
            code = "bare-function";
            fix = "write `{ ... }:` so sven knows which args to fill";
          }
        else
          let
            fa = functionArgs v;
            mine = filter isRen (attrNames fa);
            asked = listToAttrs (
              map (n: {
                name = n;
                value = argAt s n;
              }) mine
            );
            missing = filter (n: asked.${n} == [ ] && !fa.${n}) mine;
            got = listToAttrs (
              concatMap (
                n:
                if asked.${n} == [ ] then
                  [ ]
                else
                  [
                    {
                      name = n;
                      value = head asked.${n};
                    }
                  ]
              ) mine
            );
            rest = b.removeAttrs fa mine;
          in
          if missing != [ ] then
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
        if !isFunction e.value then
          (if e ? raw then "${e.origin}|raw${toString e.raw}|${e.from.id}" else e.origin) # static content: once per receiver (Ren r13 rule 9)
        else
          "${e.origin}|"
          + concatStringsSep "," (
            map (
              n:
              if n == "scope" then
                e.from.id
              else if kinds ? ${n} then
                ((nearest n e.from).id or "")
              else if elem n sinkNames then
                ((receiverIn n (nearestFirst e.from)).id or "") # a sink arg: the receiver it reads from
              else
                ""
            ) (attrNames (functionArgs e.value))
          );
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
              err x.from "${x.e.origin}: ${x.error}"
            else
              err r.id "sink ${k}: element of ${x.e.origin} from ${x.e.from.id} fails `of`"
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
      emitted =
        concatMap
          (
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
              [ (err x.from "${e.origin}: ${x.error}") ]
          ) # a record or a message; `from` is always the giver
          (filter (e: e.key == "errors") given);

      # ── run: sinks feed drivers, drivers feed sources, Nix laziness closes the loop. Every output is a query ──
      receivers = k: filter (s: byTo ? "${k}@${s.id}") scopes;
      # one reduction per (sink, receiver), shared by the `reduced` query, the errors and every arg that reads the sink
      memo = listToAttrs (
        map (k: {
          name = k;
          value = listToAttrs (
            map (r: {
              name = r.id;
              value = reduceAt k r;
            }) (receivers k)
          );
        }) sinkNames
      );
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
      # ── facts and invariants: the fleet as ground atoms; `sven.invariants.<name>` gives Datalog rules over them.
      # A true `bad:` atom is a violation; an undefined one (a cycle through `not`) is an incomplete answer, never a pass.
      facts =
        map (s: "scope:${s.id}") scopes
        ++ map (s: "kind:${s.kind}:${s.id}") scopes
        ++ concatMap (n: map (s: "has:${n}:${s.id}") (filter (s: active.${n}.${s.id}) unsorted)) aspectNames
        ++ map (e: "edge:${e.sink}:${e.from}:${e.to}") graph.edges
        ++ map (e: "error:${e.code or "error"}:${e.from}") errorsAll
        # field values of each scope's instance: `ref:FIELD:ID:KIND:NAME` for a ref, `val:FIELD:ID:VALUE` for a string, int or bool
        ++ concatMap (
          s:
          concatMap
            (
              f:
              let
                v = s.${f};
              in
              if isAttrs v && v ? kind && v ? name && b.isString v.kind then
                [ "ref:${f}:${s.id}:${v.kind}:${v.name}" ]
              else if isList v then
                concatMap (
                  x:
                  if isAttrs x && x ? kind && x ? name && b.isString x.kind then
                    [ "ref:${f}:${s.id}:${x.kind}:${x.name}" ]
                  else if b.isString x || b.isInt x then
                    [ "val:${f}:${s.id}:${toString x}" ]
                  else
                    [ ]
                ) v
              else if b.isString v || b.isInt v then
                [ "val:${f}:${s.id}:${toString v}" ]
              else if b.isBool v then
                [ "val:${f}:${s.id}:${if v then "true" else "false"}" ]
              else
                [ ]
            )
            (
              filter (
                f:
                !elem f [
                  "kind"
                  "name"
                  "key"
                  "parent"
                  "path"
                  "id"
                  "up"
                  "rup"
                  "__here"
                ]
              ) (attrNames s)
            )
        ) unsorted;
      check =
        let
          D = static.datalog;
          invs = top.invariants or { };
          rulesOf =
            n:
            let
              f = invs.${n};
            in
            if isFunction f then
              f {
                inherit
                  scopes
                  graph
                  active
                  facts
                  ;
                sven = sven;
              }
            else
              f;
          rules = concatMap rulesOf (attrNames invs);
          mentioned = listToAttrs (
            map (a: {
              name = a;
              value = true;
            }) (concatMap (r: r.pos or [ ] ++ r.neg or [ ]) rules)
          );
          m = D.wfs (rules ++ D.facts (filter (a: mentioned ? ${a}) facts));
          isBad = a: b.substring 0 4 a == "bad:";
          violations = filter isBad m.true;
          incomplete = filter isBad m.undefined;
        in
        {
          inherit violations incomplete;
          ok = violations == [ ] && incomplete == [ ];
          why = a: D.why (rules ++ D.facts facts) m a;
          whyNot = a: D.whyNot (rules ++ D.facts facts) m a;
          proof = a: D.proof (rules ++ D.facts facts) m a;
          invariants = attrNames invs;
        };
      lib = static // {
        inherit
          holds
          graph
          declaredIn
          labels
          floor
          schema
          ; # queries readable inside the fleet (docs); `check` and `context` read errors, so not here
        inherit
          stage
          change
          program
          grants
          diffData
          without
          ;
        inherit (grants) grant narrow allowed; # agent tools, inside the fleet too
        all = ps: {
          __all = ps;
          __functor = self: holds self;
        };
        not = p: {
          __not = p;
          __functor = self: holds self;
        };
        within = p: {
          __within = p;
          __functor = self: holds self;
        };
        has = p: {
          __has = p;
          __functor = self: holds self;
        };
        same =
          x: y: isAttrs x && isAttrs y && x ? kind && y ? kind && x.kind == y.kind && x.name == y.name; # total: a non-instance is never the same
        nearest = k: nearest k.__kind;
        scopesOf = x: filter (s: s.kind == x.kind && s.name == x.name) scopes;
        cascade = path: foldl' (a: x: if a != null then a else (get path x).ok or null) null; # first answer along a list of scopes
      };
      # ── schema: what a fleet declares, as JSON-safe data (no functions): for agents and docs ──
      fieldsOf =
        t:
        if isType t then
          {
            type = typeName t;
          }
          // (if t ? __kind then { ref = t.__kind; } else { })
          // (
            if
              t ? default
              && (
                b.isString t.default
                || b.isInt t.default
                || b.isBool t.default
                || t.default == null
                || isList t.default
              )
            then
              { default = t.default; }
            else
              { }
          )
          // (if t ? defaultFrom then { derived = true; } else { })
        else if isAttrs t then
          mapAttrs (_: fieldsOf) t
        else
          { type = b.typeOf t; };
      sinkOf' =
        v:
        let
          d = if isAttrs v then v else { };
        in
        {
          reduce = if d ? reduce then d.reduce.name or "custom" else "list";
          of = if d ? of then typeName d.of else null;
          feeds = filter (
            k:
            !elem k [
              "reduce"
              "of"
              "at"
              "out"
            ]
          ) (attrNames d);
          out = d ? out;
          conditional = d ? at;
        };
      schema = {
        kinds = mapAttrs (k: d: {
          fields = fieldsOf (d.fields or { });
          spawns = attrNames (d.spawns or { });
          sinks = mapAttrs (_: sinkOf') (d.sinks or { });
          instances = length (instNames k);
          scopes = length (filter (s: s.kind == k) scopes);
        }) (top.kinds or { });
        aspects = mapAttrs (n: a: {
          keys = filter (
            k:
            !elem k [
              "at"
              "order"
              "__aspect"
            ]
          ) (attrNames a);
          cycle = a ? cycle;
          files = declaredIn [
            "aspects"
            n
          ];
          activeAt = length (filter (s: active.${n}.${s.id}) unsorted);
        }) aspects;
        invariants = attrNames (top.invariants or { });
        queries = [
          "errors"
          "graph"
          "scopes"
          "active"
          "reduced"
          "undefined"
          "declaredIn"
          "facts"
          "check"
          "schema"
          "flake"
        ];
      };
      # ── explain: why an aspect is (not) active at a scope, as a three-valued trace of its `at`, cut at a depth ──
      byId = listToAttrs (
        map (s: {
          name = s.id;
          value = s;
        }) unsorted
      );
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
        in
        if isFunction p then
          node "function" { }
        else if isList p then
          node "any" { kids = kids (d': map (q: trace d' q s) p); }
        else if p ? __all then
          node "all" { kids = kids (d': map (q: trace d' q s) p.__all); }
        else if p ? __not then
          node "not" { kids = kids (d': [ (trace d' p.__not s) ]); }
        else if p ? __within then
          node "within" { kids = kids (d': map (x: { scope = x.id; } // trace d' p.__within x) (above s)); }
        else if p ? __has then
          node "has" {
            kids = kids (d': map (x: { scope = x.id; } // trace d' p.__has x) (byParent.${s.id} or [ ]));
          }
        else if p ? __functor then
          node "function" { }
        else if p ? __kind then
          node "kind" { kind = p.__kind; }
        else if p ? __aspect then
          node "aspect" {
            aspect = p.__aspect;
            kids = kids (d': [ (trace d' (aspects.${p.__aspect}.at or [ ]) s) ]);
          }
        else
          node "instance" { instance = "${p.kind or "?"}:${p.name or "?"}"; };
      explain =
        n: id: depth:
        if !(aspects ? ${n}) then
          errWith "explain" "no aspect ${n}" {
            code = "unknown-aspect";
            near = near n aspectNames;
          }
        else if !(byId ? ${id}) then
          errWith "explain" "no scope ${id}" {
            code = "unknown-scope";
            near = near id (attrNames byId);
          }
        else
          let
            s = byId.${id};
            v = s.__here.${n};
          in
          {
            aspect = n;
            scope = id;
            active = if v == null then "undefined" else v;
            at = trace depth (aspects.${n}.at or [ ]) s;
            gives = map (e: {
              inherit (e) sink;
              to = e.to;
            }) (filter (e: e.origin == "aspect ${n}" && e.from == id) graph.edges);
            files = declaredIn [
              "aspects"
              n
            ];
          };
      # ── the agent surface: JSON-safe answers, every list says when it was cut ──
      cut = max: xs: {
        items = b.genList (i: b.elemAt xs i) (if length xs < max then length xs else max);
        truncated = {
          shown = if length xs < max then length xs else max;
          of = length xs;
        };
      };
      context =
        id:
        {
          maxEdges ? 20,
          maxAspects ? 50,
        }:
        if !(byId ? ${id}) then
          errWith "context" "no scope ${id}" {
            code = "unknown-scope";
            near = near id (attrNames byId);
          }
        else
          let
            s = byId.${id};
          in
          static.jsonSafe {
            scope = id;
            inherit (s) kind name;
            parent = if s.parent == null then null else s.parent.id;
            children = map (c: c.id) (byParent.${id} or [ ]);
            aspects = cut maxAspects (filter (n: active.${n}.${id}) aspectNames);
            undefined = map (x: x.aspect) (filter (x: x.scope == id) undefined);
            given = cut maxEdges (filter (e: e.from == id) graph.edges);
            received = cut maxEdges (filter (e: e.to == id) graph.edges);
            errors = filter (e: e.from == id) errorsAll;
          };
      agent = static.jsonSafe {
        inherit schema;
        errors = errorsAll;
        check = { inherit (check) violations incomplete ok; };
        undefined = undefined;
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
          hits = b.sort (p: q: p.depth < q.depth || p.depth == q.depth && p.key < q.key) (
            filter (x: x.key != id) reached
          );
        in
        if !(byId ? ${id}) then
          errWith "impact" "no scope ${id}" {
            code = "unknown-scope";
            near = near id (attrNames byId);
          }
        else if bad != [ ] then
          errWith "impact" "no sink ${head bad}" {
            code = "unknown-sink";
            near = near (head bad) sinkNames;
          }
        else
          let
            c = cut max (
              map (x: {
                scope = x.key;
                inherit (x) depth via;
              }) hits
            );
          in
          {
            reached = c.items;
            inherit (c) truncated;
            inherit hops;
          };
      # ── labels by file path prefix (`sven.labels."agent/" = { trust = 1; }`): an aspect's label is the meet (the
      # lowest trust) over the files that declare it; an element carries its aspect's label; `floor n` lists what is below ──
      labelTable = top.labels or { };
      labelOf =
        n:
        let
          files = declaredIn [
            "aspects"
            n
          ];
          ms = concatMap (
            f:
            map (
              p:
              labelTable.${p}
              // {
                prefix = p;
                file = f;
              }
            ) (filter (p: b.match ".*/${p}.*" f != null) (attrNames labelTable))
          ) files;
        in
        if ms == [ ] then
          null
        else
          foldl' (a: x: if a == null || (x.trust or 0) < (a.trust or 0) then x else a) null ms;
      labels = listToAttrs (
        concatMap (
          n:
          let
            l = labelOf n;
          in
          if l == null then
            [ ]
          else
            [
              {
                name = n;
                value = l;
              }
            ]
        ) aspectNames
      );
      floor =
        t:
        map
          (
            e:
            let
              n = b.substring 7 (b.stringLength e.origin) e.origin;
            in
            {
              edge = e;
              aspect = n;
              inherit (labels.${n}) trust file prefix;
            }
          )
          (
            filter (
              e:
              let
                n = b.substring 7 (b.stringLength e.origin) e.origin;
              in
              b.substring 0 7 e.origin == "aspect " && labels ? ${n} && (labels.${n}.trust or 0) < t
            ) graph.edges
          );
      errorsAll =
        loadErrors
        ++ declErrors [ ]
        ++ concatMap (k: concatMap (n: instErrors k n [ ]) (instNames k)) kindNames
        ++ treeErrors
        ++ atErrors
        ++ orderErrors
        ++ requestErrors
        ++ reduceErrors
        ++ emitted;
      self = {
        inherit
          scopes
          active
          reduced
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
              mapAttrs (_: v: if isAttrs v && v ? kind && v ? name then "${v.kind}:${v.name}" else v) (
                removeAttrs i [
                  "kind"
                  "name"
                ]
              )
            )
          ) instances.${k}
        ) kinds;
        errors = errorsAll;
        flake = if top ? flake && scopes != [ ] then (fill (head scopes) top.flake).ok or null else null;
        # stored queries: `sven.queries.<name> = { host, r, ... }: …`. `r` is this result; the other formals are the
        # query's parameters, required unless they have a default. `ask name args` never throws: a missing or unknown
        # parameter, or an unknown query, is an error record.
        queries = mapAttrs (
          n: f:
          let
            fa = functionArgs f;
            ps = filter (a: a != "r") (attrNames fa);
          in
          {
            required = filter (a: !fa.${a}) ps;
            optional = filter (a: fa.${a}) ps;
          }
        ) (top.queries or { });
        ask =
          n: args:
          if !((top.queries or { }) ? ${n}) then
            errWith "ask" "no query ${n}" {
              code = "unknown-query";
              near = near n (attrNames (top.queries or { }));
            }
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
              static.jsonSafe (top.queries.${n} (args // { r = self; }));
      };
    in
    self;
  # grants that only narrow: a grant names scope id prefixes and sinks (null: every sink). Two grants meet: a scope
  # stays when one prefix holds the other (the longer is kept), sinks intersect. There is no way to widen.
  hasPrefix = p: s: b.substring 0 (b.stringLength p) s == p;
  grants = rec {
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
            if hasPrefix p q then
              [ q ]
            else if hasPrefix q p then
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
    allowed = g: e: any (p: hasPrefix p e.to) g.scopes && (g.sinks == null || elem e.sink g.sinks);
  };
  # data with no functions: it can be hashed, rendered as JSON and read back
  isData =
    v:
    if isFunction v then
      false
    else if isList v then
      all isData v
    else if isAttrs v then
      (if v ? __functor then false else all (k: isData v.${k}) (attrNames v))
    else
      true;
  # stage: an agent's change, in quarantine. Nothing changes; two evals compare. `ok` only when nothing new is wrong.
  stage =
    {
      base,
      change,
      rejected ? [ ],
      grant ? null,
      invariants ? true,
      r0 ? eval base,
    }: # r0: the base already evaluated
    let

      r1 = eval {
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
          has = listToAttrs (
            map (y: {
              name = k y;
              value = true;
            }) ys
          );
        in
        filter (x: !(has ? ${k x})) xs;
      ids = r: map (s: s.id) r.scopes;
      activeList =
        r:
        concatMap (n: map (id: "${n}@${id}") (filter (id: r.active.${n}.${id}) (attrNames r.active.${n}))) (
          attrNames r.active
        );
      sha =
        if isPath change then
          b.hashFile "sha256" change
        else if isData change then
          b.hashString "sha256" (b.toJSON change)
        else
          null;
      newEdges = minus keyG r1.graph.edges r0.graph.edges;
      errors = minus keyE r1.errors r0.errors;
      bad = if invariants then filter (a: !elem a r0.check.violations) r1.check.violations else [ ];
      refused =
        (
          if sha != null && elem sha rejected then
            [
              (errWith "stage" "this change was rejected before" {
                code = "rejected";
                class = "authority";
                got = sha;
              })
            ]
          else
            [ ]
        )
        ++ (
          if grant == null then
            [ ]
          else
            map (
              e:
              errWith e.from "the change gives ${e.sink} to ${e.to}, outside the grant" {
                code = "outside-grant";
                class = "authority";
                got = e;
              }
            ) (filter (e: !grants.allowed grant e) newEdges)
        );
    in
    {
      inherit errors refused sha;
      violations = bad;
      ok = errors == [ ] && bad == [ ] && refused == [ ];
      diff = {
        scopes = {
          added = minus (x: x) (ids r1) (ids r0);
          removed = minus (x: x) (ids r0) (ids r1);
        };
        edges = {
          added = newEdges;
          removed = minus keyG r0.graph.edges r1.graph.edges;
        };
        active = {
          added = minus (x: x) (activeList r1) (activeList r0);
          removed = minus (x: x) (activeList r0) (activeList r1);
        };
      };
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
      rs = map (rev: {
        inherit rev;
        r = asOf { inherit url rev module; };
      }) revs;
    in
    b.genList (
      i:
      let
        x = b.elemAt rs i;
      in
      {
        inherit (x) rev;
        errors = length x.r.errors;
        scopes = length x.r.scopes;
        changes = if i == 0 then [ ] else diffData (b.elemAt rs (i - 1)).r.data x.r.data;
      }
    ) (length rs);
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
      r = eval (mk keep);
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
        at = "program[${toString i}]";
        kinds = r.schema.kinds;
      in
      if !isAttrs o || !(o ? op) then
        [
          (errWith at "not an op" {
            code = "program";
            want = "{ op = …; }";
          })
        ]
      else if o.op == "set" || o.op == "ref" then
        (
          if !(isList (o.path or null)) || o.path == [ ] then
            [ (errWith at "path must be a non-empty list" { code = "program"; }) ]
          else
            let
              k = head o.path;
            in
            if !(kinds ? ${k}) then
              [
                (errWith at "no kind ${k}" {
                  code = "program";
                  near = near k (attrNames kinds);
                })
              ]
            else if length o.path > 2 && !((kinds.${k}.fields or { }) ? ${b.elemAt o.path 2}) then
              [
                (errWith at "kind ${k} has no field ${b.elemAt o.path 2}" {
                  code = "program";
                  near = near (b.elemAt o.path 2) (attrNames (kinds.${k}.fields or { }));
                })
              ]
            else if o.op == "ref" && !(kinds ? ${o.kind or ""}) then
              [ (errWith at "no kind ${o.kind or "?"}" { code = "program"; }) ]
            else
              [ ]
        )
      else if o.op == "place" then
        (
          if !(r.schema.aspects ? ${o.aspect or ""}) then
            [
              (errWith at "no aspect ${o.aspect or "?"}" {
                code = "program";
                near = near (o.aspect or "") (attrNames r.schema.aspects);
              })
            ]
          else
            [ ]
        )
      else if o.op == "new" then
        (
          if !(kinds ? ${o.kind or ""}) then
            [ (errWith at "no kind ${o.kind or "?"}" { code = "program"; }) ]
          else
            [ ]
        )
      else
        [
          (errWith at "unknown op ${toString o.op}" {
            code = "program";
            near = near (toString o.op) [
              "set"
              "ref"
              "place"
              "new"
            ];
          })
        ];
    validate = r: prog: b.concatLists (b.genList (i: opErrors r i (b.elemAt prog i)) (length prog));
    # the program as one sven module (a function: refs need `sven`)
    toModule =
      prog:
      { sven, ... }:
      let
        nest = path: v: b.foldl' (acc: k: { ${k} = acc; }) v (reverse path);
        refOf = x: if isAttrs x && x ? ref then sven.${x.ref.kind}.${x.ref.name} else x;
        one =
          o:
          if o.op == "set" then
            nest o.path o.value
          else if o.op == "ref" then
            nest o.path sven.${o.kind}.${o.name}
          else if o.op == "place" then
            { aspects.${o.aspect}.at = [ { inherit (o) kind name; } ]; }
          else
            { ${o.kind}.${o.name} = mapAttrs (_: refOf) (o.fields or { }); };
      in
      {
        imports = map (o: { sven = one o; }) prog;
      };
    dryRun =
      {
        base,
        prog,
        grant ? null,
        rejected ? [ ],
        r ? eval base,
      }:
      let
        errs = validate r prog;
      in
      if errs != [ ] then
        {
          ok = false;
          valid = false;
          errors = errs;
        }
      else
        let
          s = stage {
            inherit base grant rejected;
            r0 = r;
            change = toModule prog;
          };
        in
        removeAttrs s [
          "render"
          "sha"
        ]
        // {
          valid = true;
          sha = b.hashString "sha256" (b.toJSON prog);
        };
    render = b.toJSON;
  };
  # a change as data: set one declaration path (`change.set [ "host" "web-1" "port" ] 8080`)
  change = {
    set = path: value: { sven = b.foldl' (acc: k: { ${k} = acc; }) value (reverse path); };
  };
in
{
  lib = static // {
    inherit
      eval
      stage
      change
      grants
      diffData
      asOf
      history
      without
      program
      ;
    inherit (grants) grant narrow allowed;
    mkFlake = m: (eval m).flake;
  };
}
