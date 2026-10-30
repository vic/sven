# Rules over `result.facts`. A true `bad:` atom is a violation. Facts: kind:K:ID, has:ASPECT:ID, val:FIELD:ID:VALUE, …
{ yen, lib, ... }:
{
  # no server runs a desktop
  yen.invariants.no-desktop-on-servers =
    { scopes, ... }:
    map (s: {
      head = "bad:desktop-on-server:${s.name}";
      pos = [ "has:desktop:${s.id}" ];
    }) (lib.filter (s: yen.lib.holds yen.kinds.host s && s.form == "server") scopes);
  # no two hosts share an address: a rule across machines
  yen.invariants.unique-addr =
    { scopes, ... }:
    let
      hosts = lib.filter (s: yen.lib.holds yen.kinds.host s) scopes;
    in
    lib.concatMap (
      a:
      map (b: {
        head = "bad:same-addr:${a.name}:${b.name}";
        pos = [
          "val:addr:${a.id}:${a.addr}"
          "val:addr:${b.id}:${a.addr}"
        ];
      }) (lib.filter (b: a.name < b.name) hosts)
    ) hosts;
}
