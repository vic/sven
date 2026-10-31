let
  # every code the engine can give, read from its source: `code = "x"` and `code = if … then "x" else "y"`
  codesOf =
    src:
    builtins.sort builtins.lessThan (
      builtins.attrNames (
        builtins.listToAttrs (
          map
            (c: {
              name = c;
              value = null;
            })
            (
              builtins.concatMap (
                m:
                builtins.filter builtins.isString (
                  builtins.concatMap (x: if builtins.isList x then x else [ ]) (
                    builtins.split ''"([a-z-]+)"'' (builtins.head m)
                  )
                )
              ) (builtins.filter builtins.isList (builtins.split "code = ([^;]*);" src))
            )
        )
      )
    );
  meaning = {
    arg = "an element asks for an arg that has no answer";
    at = "`at` holds a value that is not a predicate";
    bare-function = "an element is a function without named args (`x: …`): wrap it as `{ ... }:`";
    check = "a field value or a stored query parameter fails its type";
    cycle = "an instance appears twice on its own scope path: `spawns` loops";
    error = "a message from an aspect's `errors` key";
    module = "a module asks for an arg that has no answer";
    of = "a sink element fails the sink's `of` type";
    order = "an `order` answer is not a number";
    spawns = "a `spawns` function gives no attrset, or an instance in it is no attrset";
    tree-request = "a cycle asks the tree something it does not answer (want nearest, parent, children, scopesOf or holds)";
    check-not-bool = "a field type's check gives no bool (a curried check, such as a gen-types one, needs its other argument)";
    external-not-bool = "a relation's `holds` function answers a tuple with something other than a bool";
    relation-check = "a rule derives a tuple that fails the `check` of its relation in `yen.relations`";
    invariant-data = "an invariant is data: write each rule as a function of its variables, `{ H }: { bad = H; pos = [ … ]; }`, its literals by reference";
    law-change = "a staged change declares `invariants`, `relations`, `labels` or `flake`: the law is the owner's, never a change's";
    bad-atom = "a rule literal is not a reference from `yen.facts` or `yen.relations`, or a term is not a variable, a string, an int or a bool";
    edb-head = "a rule derives a fact yen extracts (`scope`, `instance`, `parent`, `kind`, `has`, `edge`, `error`, `ref`, `val`, or a comparison)";
    unknown-relation = "a rule names a relation that is neither extracted nor declared in `yen.relations`";
    arity = "a rule atom has the wrong number of terms for its relation";
    unsafe-rule = "a variable of the head, a negative atom or a comparison is not bound by a positive atom";
    unencodable = "a field holds a float, a function or a derivation: no fact can state it";
    merge = "`merge`: two different leaves at one path";
    missing = "a required field has no value";
    missing-param = "a stored query is asked without a required parameter";
    one = "`one`: 0 or 2+ elements";
    outside-grant = "a staged change can reach a scope outside its grant";
    program = "a change program op is not valid";
    query-untyped = "a stored query is not `{ params; answer; }`: `ask` cannot check its parameters";
    ref = "a field or a stored query parameter wants a ref (an instance, a kind, an aspect) and got something else";
    rejected = "a staged change was rejected before (its sha is in `rejected`)";
    two-answers = "one declaration leaf has two different values";
    reserved = "a sink is named `scope` or `sinks`: those names are fixed args of every element";
    unknown-aspect = "a query names an aspect that does not exist";
    unknown-key = "a module, `yen` or a kind declares a key yen does not read (yen modules are not NixOS modules)";
    unknown-field = "an instance sets a field its kind does not declare";
    unknown-instance = "a ref from JSON names an instance that does not exist";
    unknown-param = "a stored query is asked with a parameter it does not take";
    unknown-query = "`result.ask` names a stored query that does not exist";
    unknown-scope = "a query names a scope id that does not exist";
    unknown-sink = "a query names a sink that does not exist";
  };
in
{
  title = "Error codes";
  description = "Every error code yen gives, read from the engine source, with what it means.";
  section = "reference";
  order = 3;
  route = "reference/errors";

  body =
    { docs, inputs, ... }:
    let
      codes = codesOf (builtins.readFile (inputs.yen + "/default.nix"));
    in
    [
      ''
        An error record has `error` and `from` for people, and `code`, `path`, `got`, `want`, `fix`, `class` and `near`
        for tools. `class` is `fixable` (an edit to the data fixes it) or `authority` (no edit by this author can).
        The codes below are read from the engine source when the docs are written.
      ''
      (docs.table [ "Code" "Meaning" ] (
        map (c: [
          "`${c}`"
          (meaning.${c} or "")
        ]) codes
      ))
      (docs.links [
        {
          title = "Errors as data";
          href = "/principles/errors/";
          description = "Records, your own checks, and warnings.";
        }
      ])
    ];

  # a new code in the engine fails this check until it has a meaning here
  checks =
    {
      inputs,
      eq,
      yes,
      no,
      ...
    }:
    {
      every-code-explained = yes (
        builtins.all (c: meaning ? ${c}) (codesOf (builtins.readFile (inputs.yen + "/default.nix")))
      );
    };
}
