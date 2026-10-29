# yen shacl oracles. Run: nix-instantiate --eval --strict tests/shacl.nix -A failed   (expect [ ])
let
  yen = (import ../default.nix).lib;
  rdf = yen.rdf;
  b = builtins;

  fix =
    { yen, ... }:
    {
      yen.kinds.fleet = {
        spawns.host = _: yen.host;
      };
      yen.kinds.host = {
        fields = {
          port = yen.lib.is b.isInt;
          rack = yen.kinds.fleet;
        };
      };
      yen.fleet.main = { };
      yen.host.web = {
        port = 80;
        rack = yen.fleet.main;
      };
    };
  fleet = ms: yen.eval { imports = ms; };
  r = fleet [ fix ];
  r2 = fleet [ fix ];
  rRev = fleet (
    b.genList (
      i:
      b.elemAt [
        fix
        (
          { yen, ... }:
          {
            yen.host.db.port = 1;
          }
        )
      ] (1 - i)
    ) 2
  );
  rFwd = fleet [
    (
      { yen, ... }:
      {
        yen.host.db.port = 1;
      }
    )
    fix
  ];

  ttl = rdf.shacl r;
  tr = rdf.triples r;
  has = s: l: b.any (x: x == s) l;
  contains = needle: s: b.match ".*${needle}.*" s != null;
  shapeCount =
    s:
    b.length (
      b.filter (x: x == "a sh:NodeShape ;" || b.match ".* a sh:NodeShape ;" x != null) (
        b.filter b.isString (b.split "\n" s)
      )
    );
  f = "<https://yen.dev/fleet/";
in
rec {
  checks = {
    node-shape-per-spawned-kind =
      shapeCount ttl == 2
      && contains "kind/host> a sh:NodeShape" ttl
      && contains "kind/fleet> a sh:NodeShape" ttl;
    no-shape-for-kind-without-scopes =
      !(contains "kind/ghost>" (
        rdf.shacl (fleet [
          fix
          (
            { yen, ... }:
            {
              yen.kinds.ghost = { };
            }
          )
        ])
      ));
    ref-field-has-class = contains "field/rack> ; sh:maxCount 1 ; sh:class ${f}kind/fleet>" ttl;
    int-field-no-class = contains "field/port> ; sh:maxCount 1 ; . ;" ttl;
    parent-class-from-spawner = contains "yen/parent> ; sh:class ${f}kind/fleet>" ttl;
    int-triple-typed = has "${f}scope/fleet:main/host:web> ${f}field/port> \"80\"^^<http://www.w3.org/2001/XMLSchema#integer> ." tr;
    ref-triple-iri = has "${f}scope/fleet:main/host:web> ${f}field/rack> ${f}instance/fleet/main> ." tr;
    no-engine-key-triples = !(b.any (x: contains "field/(kind|name|key|parent|path|id|up|rup)>" x) tr);
    deterministic-two-evals = ttl == rdf.shacl r2 && tr == rdf.triples r2;
    stable-under-module-order =
      rdf.shacl rRev == rdf.shacl rFwd && rdf.triples rRev == rdf.triples rFwd;
  };
  failed = b.filter (n: !checks.${n}) (b.attrNames checks);
}
