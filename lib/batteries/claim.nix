# a reduce: each key has one owner. Two givers of one key is an error, unless `rank` (a number from a value)
# picks one highest. value: { <key> = value; }
#   sinks.addrs.reduce = claim { key = v: v.addr; };
let
  b = builtins;
  pair = name: value: { inherit name value; };
  ids = es: b.sort b.lessThan (map (e: e.from.id) es);
  # one entry per distinct giver, the first it gave
  byGiver = es: b.attrValues (b.listToAttrs (map (e: pair e.from.id e) (reverse es)));
  reverse = xs: b.genList (i: b.elemAt xs (b.length xs - 1 - i)) (b.length xs);
in
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
}
