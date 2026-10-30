# rdf.nix: an eval result as sorted, de-duplicated N-Triples, and its content hash. Builtins only.
let
  b = builtins;
  base = "https://yen.dev/fleet/";
  bad = [
    "%"
    " "
    "\""
    "<"
    ">"
    "{"
    "}"
    "|"
    "\\"
    "^"
    "`"
    "\n"
    "\r"
    "\t"
  ];
  iriPart = b.replaceStrings bad [
    "%25"
    "%20"
    "%22"
    "%3C"
    "%3E"
    "%7B"
    "%7D"
    "%7C"
    "%5C"
    "%5E"
    "%60"
    "%0A"
    "%0D"
    "%09"
  ];
  iri = ns: x: "<${base}${ns}/${iriPart x}>";
  pred = n: "<${base}yen/${n}>";
  fpred = n: "<${base}field/${iriPart n}>";
  xsd = "http://www.w3.org/2001/XMLSchema#";
  type = "<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>";
  lit =
    s: "\"${b.replaceStrings [ "\\" "\"" "\n" "\r" "\t" ] [ "\\\\" "\\\"" "\\n" "\\r" "\\t" ] s}\"";
  h16 = s: b.substring 0 16 (b.hashString "sha256" s);
  triple =
    s: p: o:
    "${s} ${p} ${o} .";
  parentOf =
    id:
    let
      m = b.match "(.*)/[^/]*" id;
    in
    if m == null then [ ] else b.head m;

  inst = k: n: "<${base}instance/${iriPart k}/${iriPart n}>";
  #: lib.rdf.triples :: result -> [ string ] -- the eval result as N-Triples lines, sorted
  triples =
    r:
    let
      engineKeys = [
        "kind"
        "name"
        "key"
        "parent"
        "path"
        "id"
        "up"
        "rup"
        "__here"
      ];
      fieldObj =
        v:
        if b.isString v then
          lit v
        else if b.isInt v then
          "\"${toString v}\"^^<${xsd}integer>"
        else if b.isBool v then
          "\"${if v then "true" else "false"}\"^^<${xsd}boolean>"
        else if b.isAttrs v && b.isString (v.kind or null) && b.isString (v.name or null) then
          inst v.kind v.name
        else
          null;
      fields =
        n: s:
        b.concatMap (
          k:
          let
            o = fieldObj s.${k};
          in
          if o == null then [ ] else [ (triple n (fpred k) o) ]
        ) (b.filter (k: !b.elem k engineKeys) (b.attrNames s));
      scope =
        s:
        let
          n = iri "scope" s.id;
        in
        [
          (triple n type (iri "kind" s.kind))
          (triple n (pred "name") (lit s.name))
          (triple n (pred "instance") (inst s.kind s.name))
        ]
        ++ fields n s
        ++ (
          let
            p = parentOf s.id;
          in
          if p == [ ] then [ ] else [ (triple n (pred "parent") (iri "scope" p)) ]
        );
      on = a: b.filter (id: r.active.${a}.${id}) (b.attrNames r.active.${a});
      aspect = a: map (id: triple (iri "scope" id) (pred "has") (iri "aspect" a)) (on a);
      edge =
        e:
        let
          n = iri "edge" (h16 "${e.sink}|${e.from}|${e.to}|${e.origin}");
        in
        [
          (triple n (pred "sink") (lit e.sink))
          (triple n (pred "from") (iri "scope" e.from))
          (triple n (pred "to") (iri "scope" e.to))
          (triple n (pred "origin") (lit e.origin))
        ];
      error =
        e:
        let
          n = iri "error" (h16 "${e.from}|${e.error}");
        in
        [
          (triple n (pred "message") (lit e.error))
          (triple n (pred "at") (lit e.from))
        ];
      # every instance is typed, so a ref field (an instance IRI) meets `sh:class`; data kinds have instances and no scopes
      typed = k: n: [
        (triple (inst k n) type (iri "kind" k))
        (triple (inst k n) (pred "name") (lit n))
      ];
      instances =
        b.concatLists (
          b.attrValues (b.mapAttrs (k: ns: b.concatMap (typed k) (b.attrNames ns)) (r.data or { }))
        )
        ++ b.concatMap (s: typed s.kind s.name) scopes;
      scopes = r.scopes or r.graph.scopes; # inside a fleet only the graph is visible
      all =
        b.concatMap scope scopes
        ++ instances
        ++ b.concatMap aspect (b.attrNames r.active)
        ++ b.concatMap edge r.graph.edges
        ++ b.concatMap error r.errors;
      uniq = map (i: i.key) (
        b.genericClosure {
          startSet = map (key: { inherit key; }) all;
          operator = _: [ ];
        }
      );
    in
    b.sort b.lessThan uniq;

  #: lib.rdf.ntriples :: result -> string -- the eval result as one N-Triples document
  ntriples = r: b.concatStringsSep "\n" (triples r) + "\n";

  # SHACL shapes (Turtle) from r.schema; a leaf field is an attrset with a string `type`.
  #: lib.rdf.shacl :: result -> string -- SHACL shapes (Turtle) from the result schema
  shacl =
    r:
    let
      kinds = r.schema.kinds;
      names = b.filter (k: kinds.${k}.scopes > 0) (b.attrNames kinds);
      kiri = k: "<${base}kind/${iriPart k}>";
      spawners = k: b.filter (p: b.elem k kinds.${p}.spawns) (b.attrNames kinds);
      isLeaf = f: b.isAttrs f && b.isString (f.type or null);
      leaves =
        fs:
        b.concatMap (
          n:
          let
            f = fs.${n};
          in
          if isLeaf f then [ { inherit n f; } ] else [ ]
        ) (b.attrNames fs);
      prop = path: extra: "  sh:property [ sh:path ${path} ;${extra} ] ;";
      parentShape =
        k:
        let
          ps = spawners k;
        in
        if b.length ps == 1 then " sh:class ${kiri (b.head ps)} ; sh:maxCount 1 ;" else " sh:maxCount 1 ;";
      fieldShape =
        l:
        prop (fpred l.n) (" sh:maxCount 1 ;" + (if l.f ? ref then " sh:class ${kiri l.f.ref} ;" else ""));
      shape =
        k:
        b.concatStringsSep "\n" (
          [
            "${kiri k} a sh:NodeShape ;"
            "  sh:targetClass ${kiri k} ;"
            (prop (pred "name") " sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ;")
            (prop (pred "parent") (parentShape k))
          ]
          ++ map fieldShape (leaves kinds.${k}.fields)
          ++ [ "  ." ]
        );
    in
    b.concatStringsSep "\n" (
      [
        "@prefix sh: <http://www.w3.org/ns/shacl#> ."
        "@prefix xsd: <${xsd}> ."
        "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ."
        ""
      ]
      ++ map (k: shape k + "\n") names
    );
in
{
  inherit triples ntriples shacl;
  #: lib.rdf.share :: result -> { ntriples; sha256; count; } -- the N-Triples with their content hash and triple count
  share =
    r:
    let
      nt = ntriples r;
    in
    {
      ntriples = nt;
      sha256 = b.hashString "sha256" nt;
      count = b.length (triples r);
    };
}
