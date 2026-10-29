{
  title = "Library index";
  description = "Every function of yen.lib, and every query of an eval result. Generated from the engine.";
  section = "reference";
  order = 1;

  body =
    { docs, engine, ... }:
    let
      code = xs: builtins.concatStringsSep ", " (map (x: "`${x}`") xs);
      # yen.lib as modules see it. A root kind needs `spawns`: `top` spawns `leaf`
      inner =
        (engine.eval (
          { yen, ... }:
          {
            yen.kinds.top.spawns.leaf = _: { };
            yen.kinds.leaf = { };
            yen.top.t = { };
            yen.flake = { ... }: builtins.attrNames yen.lib;
          }
        )).flake;
      r = engine.eval {
        yen.kinds.top = { };
        yen.top.t = { };
      };
      outer = builtins.attrNames engine;
      sub = [
        "reduce"
        "graphs"
        "datalog"
        "krn"
        "rdf"
        "program"
        "grants"
        "change"
      ];
    in
    [
      ''
        This page is computed from the engine when the docs are written. A function added to yen appears here
        without a docs edit.

        ## Outside a fleet: `(import yen).lib`
      ''
      (code (builtins.filter (n: !builtins.elem n sub) outer))
      ''
        ## Inside a fleet: `yen.lib`

        Modules get the same lib, plus predicates and queries bound to the fleet:
      ''
      (code (builtins.filter (n: !builtins.elem n outer) inner))
      ''
        ## Libraries
      ''
      (docs.table [ "Library" "Functions" ] (
        map (n: [
          "`yen.lib.${n}`"
          (code (builtins.attrNames engine.${n}))
        ]) sub
      ))
      ''
        ## Queries of an eval result: `r = yen.lib.eval module`
      ''
      (code (builtins.attrNames r))
      (docs.links [
        {
          title = "Queries";
          href = "/query/queries/";
          description = "What each query answers.";
        }
        {
          title = "Error codes";
          href = "/reference/errors/";
          description = "Every error record yen can give.";
        }
      ])
    ];

  checks =
    { engine, ... }:
    {
      has-eval = engine ? eval && engine ? stage && engine.reduce ? entries;
      inner =
        builtins.elem "holds"
          (engine.eval (
            { yen, ... }:
            {
              yen.kinds.top.spawns.leaf = _: { };
              yen.kinds.leaf = { };
              yen.top.t = { };
              yen.flake = { ... }: builtins.attrNames yen.lib;
            }
          )).flake;
    };
}
