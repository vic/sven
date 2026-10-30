{
  title = "krn: synthesis with constraints";
  description = "µKanren with finite domains in pure Nix: values that meet your rules, relations that run backward.";
  section = "query";
  order = 4;
  badge = "advanced";

  body =
    { docs, result, ... }:
    [
      ''
        Some values are not written but found: a port no other app uses, memory that fits a host, a database host in the
        right environment. `yen.lib.krn` is µKanren with constraints. It has logic variables, unification over attrsets,
        lists and scalars, and goals that run in both directions.
      ''
      (docs.file "modules/fleet.nix")
      (docs.fileWith "{6-12}" "modules/ports.nix")
      (docs.value result.flake.ports)
      ''
        `grafana` can never take 8080: `prometheus` must be lower. The same relation, read backward, says so.
      ''
      (docs.table
        [ "Goal" "Meaning" ]
        [
          [
            "`eq u v`, `fresh`, `freshNamed`, `disj`, `conde`, `project`"
            "µKanren: unify, new variables, any of, clauses, read a value"
          ]
          [
            "`neq u v`"
            "`u` and `v` never unify"
          ]
          [
            "`dom x [ … ]`, `infd xs lo hi`"
            "finite domains"
          ]
          [
            "`lefd`, `ltfd`, `plusfd x y z`, `neqfd`, `distinctfd xs`"
            "propagation over domains"
          ]
          [
            "`label xs`"
            "enumerate what is left, smallest domain first"
          ]
          [
            "`cons`, `appendo`, `membero`, `fromList`, `toList`"
            "relational lists"
          ]
          [
            "`facto rows pattern`"
            "a table of facts"
          ]
          [
            "`run n`, `runAll`, `runC n`"
            "answers; `runC` adds the constraints left on fresh variables"
          ]
          [
            "`runFuel n fuel`, `runAllFuel fuel`, `maximize fuel measure`"
            "bounded search: `{ answers; complete; }`"
          ]
        ]
      )
      (docs.caution "A search must stop" ''
        A search with no answer gives `[ ]`: turn that into an error record. A search an agent writes must have fuel:
        `complete = false` means "bounded", never "no answer". `appendo` with two unknown lists enumerates without end.
      '')
      (docs.tip "More" ''
        The reference fleet's ${
          docs.fleet "modules/query/krn.nix" null "query/krn.nix"
        } also sums guest memory under a host's RAM
        and joins host records to place a database.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    let
      p = result.flake.ports;
    in
    {
      first = eq (p.first) ([
        {
          grafana = 8081;
          loki = 8082;
          prometheus = 8080;
        }
      ]);
      count = eq (p.count) (12);
      backward = eq (p.on8080) ([
        "prometheus"
        "loki"
      ]);
      fuel = no (p.bounded.complete);
    };
}
