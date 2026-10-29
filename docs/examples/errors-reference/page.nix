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
    check = "a field value fails its type";
    cycle = "an instance appears twice on its own scope path: `spawns` loops";
    error = "a message from an aspect's `errors` key";
    module = "a module asks for an arg that has no answer";
    of = "a sink element fails the sink's `of` type";
    order = "an `order` answer is not a number";
    spawns = "a `spawns` function gives no attrset, or an instance in it is no attrset";
    tree-request = "a cycle asks the tree something it does not answer (want nearest, parent, children, scopesOf or holds)";
    merge = "`merge`: two different leaves at one path";
    missing = "a required field has no value";
    missing-param = "a stored query is asked without a required parameter";
    one = "`one`: 0 or 2+ elements";
    outside-grant = "a staged change gives an element outside its grant";
    program = "a change program op is not valid";
    ref = "a field wants an instance ref and got something else";
    rejected = "a staged change was rejected before (its sha is in `rejected`)";
    two-answers = "one declaration leaf has two different values";
    unknown-aspect = "a query names an aspect that does not exist";
    unknown-field = "an instance sets a field its kind does not declare";
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
  order = 2;
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
          href = "/concepts/errors/";
          description = "Records, your own checks, and warnings.";
        }
      ])
    ];

  # a new code in the engine fails this check until it has a meaning here
  checks =
    { inputs, ... }:
    {
      every-code-explained = builtins.all (c: meaning ? ${c}) (
        codesOf (builtins.readFile (inputs.yen + "/default.nix"))
      );
    };
}
