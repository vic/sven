# A stored query names a question. `result` is the eval result; the other args are its parameters.
{ yen, lib, ... }:
{
  yen.queries = {
    aspectsOn =
      { result, host }:
      lib.sort (a: b: a < b) (
        lib.filter (a: result.active.${a}."fleet:main/host:${host}" or false) (lib.attrNames result.active)
      );
    hostsWith =
      {
        result,
        aspect,
        kind ? "host",
      }:
      map (s: s.name) (lib.filter (s: s.kind == kind && result.active.${aspect}.${s.id}) result.scopes);
  };
}
