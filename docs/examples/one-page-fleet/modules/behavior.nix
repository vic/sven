# Aspects are active where a predicate holds; each element goes up to the nearest `os` sink.
{ yen, lib, ... }:
let
  inherit (yen.lib) same;
  inherit (yen.facts) host;
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
  # a rule across machines, checked before deploy: a host's db lives in its own environment.
  # H uses D as its db, H is in environment E, and D is not.
  yen.invariants.db-same-env =
    {
      H,
      D,
      E,
    }:
    {
      bad = H;
      pos = [
        (host.db H D)
        (host.env H E)
      ];
      neg = [ (host.env D E) ];
    };
}
