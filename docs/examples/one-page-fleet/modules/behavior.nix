# Aspects are active where a predicate holds; each element goes up to the nearest `os` sink.
{ yen, lib, ... }:
let
  inherit (yen.lib) same;
in
{
  yen.aspects.names = {
    at = yen.kinds.host;
    os =
      { host, env, ... }:
      {
        networking = {
          hostName = host.name;
          domain = env.domain;
        };
      };
  };
  yen.aspects.account = {
    at = yen.kinds.user; # no `os` sink on a user: the account lands on each host ana is on
    os =
      { user, ... }:
      {
        users.users.${user.name}.isNormalUser = true;
      };
  };
  yen.aspects.postgres = {
    at = s: lib.any (h: same h.db s) (lib.attrValues yen.host); # a fact: some host uses me as its db
    os.services.postgresql.enable = true;
  };
  # a rule across machines, checked before deploy: a host's db lives in its environment
  yen.invariants.db-same-env =
    { scopes, ... }:
    map (s: {
      head = "bad:db-other-env:${s.name}";
      pos = [ "ref:db:${s.id}:host:${s.db.name}" ];
    }) (lib.filter (s: s.kind == "host" && s.db != null && !(same s.db.env s.env)) scopes);
}
