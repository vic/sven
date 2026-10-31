# A stored query names a question. `params` gives each parameter a type; `answer` gets the parameters and `result`, the
# eval result. A parameter that names a fleet thing is a ref: a kind, an instance or an aspect, never its name.
{ yen, lib, ... }:
{
  yen.queries = {
    aspectsOn = {
      params.host = yen.kinds.host;
      answer =
        { result, host }:
        let
          s = lib.findFirst (yen.lib.same host) null result.scopes;
        in
        if s == null then
          [ ]
        else
          lib.sort (a: b: a < b) (lib.filter (a: result.active.${a}.${s.id}) (lib.attrNames result.active));
    };
    hostsWith = {
      params = {
        aspect = yen.lib.aspect;
        kind = yen.lib.opt yen.lib.kind yen.kinds.host;
      };
      answer =
        {
          result,
          aspect,
          kind,
        }:
        map (s: s.name) (
          lib.filter (yen.lib.holds (
            yen.lib.all [
              kind
              aspect
            ]
          )) result.scopes
        );
    };
  };
}
