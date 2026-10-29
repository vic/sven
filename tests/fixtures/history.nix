# A fleet that changes between two commits: the history oracle reads it at both revisions.
{ yen, ... }:
{
  yen.kinds.top.spawns.host = _: yen.host;
  yen.kinds.host.fields = {
    port = yen.lib.is builtins.isInt;
    validTo = yen.lib.opt (yen.lib.is builtins.isString) "9999-12-31";
  };
  yen.top.t = { };
  yen.host.a = {
    port = 2222;
    validTo = "2026-12-01";
  };
  yen.host.b.port = 80;
}
