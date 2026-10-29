# Aspects are active where a predicate holds; each element goes up to the nearest `os` sink.
{ yen, lib, ... }:
let
  inherit (yen.lib) same;
  v = x: { var = x; }; # a rule variable; every string is a constant
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
  # a rule across machines, as data, checked before deploy: a host's db lives in its environment.
  # H uses the host named N as its db; D is that host's scope; E is H's environment, and D is not in it.
  yen.invariants.db-same-env = [
    {
      head = [
        "bad"
        "db-other-env"
        (v "H")
      ];
      pos = [
        [
          "ref"
          "db"
          (v "H")
          "host"
          (v "N")
        ]
        [
          "instance"
          (v "D")
          "host"
          (v "N")
        ]
        [
          "ref"
          "env"
          (v "H")
          "env"
          (v "E")
        ]
      ];
      neg = [
        [
          "ref"
          "env"
          (v "D")
          "env"
          (v "E")
        ]
      ];
    }
  ];
}
