# yen rdf oracles. Run: nix-instantiate --eval --strict tests/rdf.nix -A failed   (expect [ ])
let
  yen = (import ../default.nix).lib;
  rdf = yen.rdf;
  b = builtins;

  base =
    name: msg:
    { yen, ... }:
    {
      yen.kinds.fleet = {
        spawns.host = _: yen.host;
        sinks.fw.reduce = yen.lib.reduce.set;
      };
      yen.kinds.host = {
        fields.port = yen.lib.is b.isInt;
        sinks.fw = { };
      };
      yen.fleet.main = { };
      yen.host.${name}.port = 80;
      yen.host.db.port = 5432;
      yen.aspects.web = {
        at = yen.host.${name};
        fw = 443;
      };
      yen.aspects.warn = {
        at = yen.host.db;
        errors = msg;
      };
    };
  mods = [
    (base "web" "plain")
    (
      { yen, ... }:
      {
        yen.aspects.dbsrv = {
          at = yen.host.db;
          fw = 5432;
        };
      }
    )
  ];
  fleet = ms: yen.eval { imports = ms; };
  r = fleet mods;
  rRev = fleet (b.genList (i: b.elemAt mods (1 - i)) 2);
  rMore = fleet (
    mods
    ++ [
      (
        { yen, ... }:
        {
          yen.aspects.extra = {
            at = yen.host.db;
          };
        }
      )
    ]
  );
  rEsc = fleet [ (base "we\"b\nx" "bad \"msg\"\nline2") ];

  lines = rdf.triples r;
  count = s: l: b.length (b.filter (x: b.match ".*${s}.*" x != null) l);
  uniqueCount =
    l:
    b.length (
      b.attrNames (
        b.listToAttrs (
          map (x: {
            name = x;
            value = null;
          }) l
        )
      )
    );
  escLines = rdf.triples rEsc;
in
rec {
  checks = {
    stable-under-reorder = (rdf.share r).sha256 == (rdf.share rRev).sha256;
    changed-field-changes-hash =
      (rdf.share r).sha256 != (rdf.share (fleet [ (base "web2" "plain") ])).sha256;
    extra-aspect-changes-hash = (rdf.share r).sha256 != (rdf.share rMore).sha256;
    count-is-unique-lines =
      (rdf.share r).count == uniqueCount lines && lines == b.sort b.lessThan lines;
    line-shape = b.all (l: b.substring 0 1 l == "<" && b.match ".* \\.$" l != null) lines;
    edge-per-graph-edge = r.graph.edges != [ ] && count "yen/sink>" lines == b.length r.graph.edges;
    ntriples-ends-newline = b.match ".*\n" (rdf.ntriples r) != null;
    escaped-no-raw-newline =
      escLines != [ ]
      && b.all (l: b.match ".*\n.*" l == null) escLines
      && b.any (l: b.match ".*bad \\\\\"msg\\\\\"\\\\nline2.*" l != null) escLines;
    scope-and-parent = b.elem "<https://yen.dev/fleet/scope/fleet:main/host:db> <https://yen.dev/fleet/yen/parent> <https://yen.dev/fleet/scope/fleet:main> ." lines;
  };
  failed = b.filter (n: !checks.${n}) (b.attrNames checks);
}
