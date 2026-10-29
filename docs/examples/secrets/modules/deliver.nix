{ yen, lib, ... }:
{
  # each host gets the secrets that name it
  yen.aspects.deliver = {
    at = yen.kinds.host;
    cycle =
      { scope, ... }:
      {
        secrets = lib.attrValues (lib.filterAttrs (_: s: lib.any (yen.lib.same scope) s.owners) yen.secret);
      };
  };
  # a secret that no host owns is an error, not a silent leftover
  yen.aspects.orphans = {
    at = yen.kinds.fleet;
    errors = map (s: "secret ${s.name} (${s.file}) has no owner") (
      lib.filter (s: s.owners == [ ]) (lib.attrValues yen.secret)
    );
  };
}
