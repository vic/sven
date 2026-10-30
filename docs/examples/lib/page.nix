# The API reference, extracted from the source: a line `#: <where>[, <where>…] :: <takes> -> <returns> -- <purpose>`
# above each definition in default.nix or lib/. A check fails when an API has no line, or a line names no API.
let
  b = builtins;
  # every .nix file of the engine: default.nix and lib/
  files =
    dir:
    b.concatLists (
      b.attrValues (
        b.mapAttrs (
          n: t:
          if t == "directory" then
            files (dir + "/${n}")
          else if b.match ".*\\.nix" n != null then
            [ (dir + "/${n}") ]
          else
            [ ]
        ) (b.readDir dir)
      )
    );
  docsOf =
    root:
    b.listToAttrs (
      b.concatMap
        (
          l:
          let
            m = b.match " *#: ([^ ]+(, [^ ]+)*) :: (.*) -- (.*)" l;
          in
          if m == null then
            [ ]
          else
            map (n: {
              name = n;
              value = {
                sig = b.elemAt m 2;
                does = b.elemAt m 3;
              };
            }) (b.filter b.isString (b.split ", " (b.elemAt m 0)))
        )
        (
          b.concatMap (f: b.filter b.isString (b.split "\n" (b.readFile f))) (
            [ (root + "/default.nix") ] ++ files (root + "/lib")
          )
        )
    );
  # the APIs: every function of `(import yen).lib`, nested sets walked; the fleet-bound extras of `yen.lib`; the
  # queries of an eval result, and those of `result.check`
  leaves =
    p: v:
    if b.isAttrs v && !(v ? __functor) && b.attrNames v != [ ] then
      b.concatMap (n: leaves (p ++ [ n ]) v.${n}) (b.attrNames v)
    else
      [ (b.concatStringsSep "." p) ];
  apisOf =
    engine:
    let
      result = engine.eval {
        yen.kinds.top = { };
        yen.top.t = { };
      };
      inner =
        (engine.eval (
          { yen, ... }:
          {
            yen.kinds.top.spawns.leaf = _: { };
            yen.kinds.leaf = { };
            yen.top.t = { };
            yen.flake =
              { ... }:
              {
                lib = b.attrNames yen.lib;
                facts = b.attrNames (removeAttrs yen.facts (b.attrNames yen.kinds));
              };
          }
        )).flake;
    in
    {
      lib = leaves [ "lib" ] engine;
      fleet = map (n: "yen.lib.${n}") (b.filter (n: !(engine ? ${n})) inner.lib);
      # the rule literals: the built-ins, then the ones each kind field and each relation gives
      rules = map (n: "yen.facts.${n}") inner.facts ++ [
        "yen.facts.<kind>.<field>"
        "yen.facts.<kind>.<field>.set"
        "yen.relations.<name>"
      ];
      result =
        map (n: "result.${n}") (b.attrNames result)
        ++ map (n: "result.check.${n}") (b.attrNames result.check);
    };
in
{
  title = "API reference";
  description = "Every function and query of yen: where it is, what it takes, what it returns, and what it is for. Extracted from the source.";
  section = "reference";
  order = 1;

  body =
    {
      docs,
      engine,
      inputs,
      ...
    }:
    let
      d = docsOf inputs.yen.outPath;
      apis = apisOf engine;
      cell = s: b.replaceStrings [ "|" ] [ "\\|" ] s;
      table =
        names:
        docs.table [ "API" "Takes and returns" "Purpose" ] (
          map (n: [
            "`${n}`"
            "`${cell d.${n}.sig}`"
            (cell d.${n}.does)
          ]) (b.filter (n: d ? ${n}) names)
        );
      under = p: b.filter (n: b.substring 0 (b.stringLength p) n == p);
      subs = b.filter (n: b.isAttrs engine.${n} && !(engine.${n} ? __functor)) (b.attrNames engine);
    in
    [
      ''
        This page is extracted from the source when the docs are written. Each API has one line above its
        definition: `#: <where> :: <takes> -> <returns> -- <purpose>`. A check fails when an API has no line, so the
        page always lists every function.

        Words in the signatures: a *key value* is the value of a sink key, `{ scope, sinks, ... }: …`; an *out value*
        is the value of a sink's `out` key, which gives flake outputs; a *reduce* is a sink's `reduce`; a *module* is a
        module of the target system; a *predicate* is what `at` takes; a *view* is `{ nodes; edges; }` for
        `mermaid.flowchart`; `succ` is a graph, an attrset from a node to its successors.

        ## Outside a fleet: `(import yen).lib`
      ''
      (table (b.filter (n: b.length (b.filter b.isString (b.split "\\." n)) == 2) apis.lib))
    ]
    ++ b.concatMap (s: [
      "## `lib.${s}`"
      (table (under "lib.${s}." apis.lib))
    ]) subs
    ++ [
      ''
        ## Inside a fleet: `yen.lib`

        Modules get the same lib, plus these predicates and queries bound to the fleet. They have no `result`: see
        [Inside the fleet](/query/queries/#inside-the-fleet).
      ''
      (table apis.fleet)
      ''
        ## Rules: `yen.facts` and `yen.relations`

        A rule is a function of its variables, `{ H }: { bad = H; pos = [ … ]; neg = [ … ]; }`. Its literals come
        from these references, never from strings. See [Invariants](/query/invariants/).
      ''
      (table apis.rules)
      ''
        ## Queries of an eval result: `result = yen.lib.eval module`
      ''
      (table apis.result)
      (docs.links [
        {
          title = "Queries";
          href = "/query/queries/";
          description = "What each query answers, with examples.";
        }
        {
          title = "Error codes";
          href = "/reference/errors/";
          description = "Every error record yen can give.";
        }
      ])
    ];

  checks =
    {
      engine,
      inputs,
      eq,
      ...
    }:
    let
      d = docsOf inputs.yen.outPath;
      apis = b.concatLists (b.attrValues (apisOf engine));
    in
    {
      # every API has its line, and every line names an API
      undocumented = eq (b.filter (n: !(d ? ${n})) apis) [ ];
      stale = eq (b.filter (n: !(b.elem n apis)) (b.attrNames d)) [ ];
    };
}
