# Batteries: values for keys you write. A battery names no kind, sink, aspect or field: it reads `scope` and `sinks`,
# takes a sink it reads as a ref, or is a reduce strategy. A domain's batteries live under its name. Builtins only.
let
  b = builtins;
  graphs = import ../graphs.nix;
  pair = name: value: { inherit name value; };
  hasPrefix = p: s: b.substring 0 (b.stringLength p) s == p;
  # the scope itself, or a scope under it
  own = scope: e: e.from.id == scope.id || hasPrefix "${scope.id}/" e.from.id;
  ids = es: b.sort b.lessThan (map (e: e.from.id) es);
  # one entry per distinct giver, the first it gave
  byGiver = es: b.attrValues (b.listToAttrs (map (e: pair e.from.id e) (reverse es)));
  reverse = xs: b.genList (i: b.elemAt xs (b.length xs - 1 - i)) (b.length xs);
in
{
  nixos = import ./nixos.nix;
  files = import ./files.nix;
  mermaid = import ./mermaid.nix;
  github = import ./github.nix;

  # the modules of sink `from` and `modules`, evaluated with `lib.evalModules`: any module system (NixOS options,
  # flake-parts, sini/files). `result` turns the evaluation into the value, `config` by default.
  #   out = eval-modules { from = yen.kinds.repo.sinks.files; inherit lib; modules = [ inputs.files.module ]; };
  eval-modules =
    {
      from,
      lib,
      modules ? [ ],
      specialArgs ? { },
      result ? e: e.config,
    }:
    { sinks, ... }:
    result (
      lib.evalModules {
        modules = modules ++ sinks.${from.__sink};
        inherit specialArgs;
      }
    );

  # every record of `from` except the ones given by this scope or under it, then `build` makes content of them.
  # `from` must reduce with `yen.lib.reduce.entries`: an entry knows its giver.
  #   nixos = mesh { from = yen.kinds.fleet.sinks.ssh-keys; build = keys: { programs.ssh.knownHosts = …; }; };
  mesh =
    { from, build }:
    { scope, sinks, ... }:
    build (map (e: e.value) (b.filter (e: !own scope e) sinks.${from.__sink}));

  # a reduce: each key has one owner. Two givers of one key is an error, unless `rank` (a number from a value)
  # picks one highest. value: { <key> = value; }
  #   sinks.addrs.reduce = claim { key = v: v.addr; };
  claim =
    {
      key,
      rank ? null,
    }:
    es:
    let
      groups = b.groupBy (e: key e.value) es;
      pick =
        k: g:
        let
          gs = byGiver g;
          top = if rank == null then gs else b.filter (e: rank e.value == maxOf gs) gs;
          maxOf =
            xs: b.foldl' (m: e: if rank e.value > m then rank e.value else m) (rank (b.head xs).value) xs;
        in
        if b.length top == 1 then
          {
            value = (b.head top).value;
            errors = [ ];
          }
        else
          {
            value = null;
            errors = [
              {
                error = "claim: ${k} has ${toString (b.length top)} owners: ${b.concatStringsSep ", " (ids top)}";
                code = "claim";
                got = ids top;
                want = 1;
              }
            ];
          };
      picked = b.mapAttrs pick groups;
    in
    {
      value = b.mapAttrs (_: p: p.value) (
        b.removeAttrs picked (b.filter (k: picked.${k}.errors != [ ]) (b.attrNames picked))
      );
      errors = b.concatMap (p: p.errors) (b.attrValues picked);
    };

  # a reduce: elements `{ name; value; before ? [ ]; after ? [ ]; }` in an order that meets every before and after.
  # value: the values in that order. A cycle, an unknown name or a name given twice is an error.
  #   sinks.sections.reduce = ordered;
  ordered =
    es:
    let
      vs = map (e: e.value) es;
      names = map (v: v.name) vs;
      known = n: b.elem n names;
      twice = b.filter (n: b.length (b.filter (m: m == n) names) > 1) names;
      unknown = b.filter (n: !known n) (b.concatMap (v: v.before or [ ] ++ v.after or [ ]) vs);
      # topo: a node waits for its successors. `after` is a successor; `before` makes this node a successor of the other
      succ = b.listToAttrs (
        map (
          v:
          pair v.name (
            b.filter known (v.after or [ ])
            ++ map (w: w.name) (b.filter (w: b.elem v.name (w.before or [ ])) vs)
          )
        ) vs
      );
      t = graphs.topo succ;
      byName = b.listToAttrs (map (v: pair v.name v.value) vs);
      err = code: msg: got: {
        error = "ordered: ${msg}";
        inherit code got;
      };
    in
    {
      value = map (n: byName.${n}) t.order;
      errors =
        (if twice == [ ] then [ ] else [ (err "ordered-twice" "names given twice" twice) ])
        ++ (
          if unknown == [ ] then
            [ ]
          else
            [ (err "ordered-unknown" "unknown names in before or after" unknown) ]
        )
        ++ (if t.ok then [ ] else [ (err "ordered-cycle" "a cycle among these names" t.stuck) ]);
    };
}
