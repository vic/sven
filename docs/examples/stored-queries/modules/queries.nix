# A stored query names a question. `r` is the eval result; the other args are its parameters.
{ yen, lib, ... }:
{
  yen.queries = {
    aspectsOn =
      { r, host }:
      lib.sort (a: b: a < b) (
        lib.filter (a: r.active.${a}."fleet:main/host:${host}" or false) (lib.attrNames r.active)
      );
    hostsWith =
      {
        r,
        aspect,
        kind ? "host",
      }:
      map (s: s.name) (lib.filter (s: s.kind == kind && r.active.${aspect}.${s.id}) r.scopes);
  };
}
