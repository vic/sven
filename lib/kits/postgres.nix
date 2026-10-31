#: lib.kits.postgres :: module -- one postgres server serves the clients of its own assembly and exports a DSN record
# A client says `database` and `user` (its interface) and exports them to its assembly. The server creates every
# role and database, listens on the network, lets only the machine address of each client of its own assembly in
# (one pg_hba line per client), and exports `dsn = { host; port; }`; each client writes its connection string to
# /etc/postgres/<database>.dsn. Needs a machine field `addr`.
# shortcut: the line is `trust` by address, no password; upgrade when a generator can deploy one file to both sides.
#   imports = [ inputs.yen.lib.kits.postgres ];
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  str = lib.types.str;
  member =
    role:
    all [
      yen.kinds.member
      (s: same (s.kit or null) yen.kit.postgres && s.role == role)
    ];
  peers =
    role: member: exports:
    lib.filter (e: same e.assembly member.assembly && e.role == role) exports;
in
{
  yen.kit.postgres = {
    roles = {
      server.interface.port = {
        type = lib.types.port;
        default = 5432;
      };
      client.interface = {
        database.type = str;
        user.type = str;
      };
    };
    constraints.roles.server = {
      min = 1;
      max = 1;
    };
    exports = [
      "dsn"
      "database"
      "user"
    ];
  };
  yen.aspects.postgres-server = {
    at = member "server";
    exports =
      { scope, member, ... }:
      {
        dsn = {
          host = scope.parent.addr;
          port = member.settings.port;
        };
      };
    nixos =
      { member, exports, ... }:
      let
        clients = peers "client" member exports;
      in
      {
        services.postgresql = {
          enable = true;
          enableTCPIP = true;
          settings.port = member.settings.port;
          ensureDatabases = map (c: c.value.database) clients;
          ensureUsers = map (c: { name = c.value.user; }) clients;
          authentication = lib.concatMapStrings (
            c: "host ${toString c.value.database} ${toString c.value.user} ${c.machine.addr}/32 trust\n" # settings-typed reports a wrong type; no abort here
          ) clients;
        };
      };
  };
  yen.aspects.postgres-client = {
    at = member "client";
    exports =
      { member, ... }:
      {
        inherit (member.settings) database user;
      };
    nixos =
      { member, exports, ... }:
      let
        s = member.settings;
      in
      {
        environment.etc = lib.listToAttrs (
          map (e: {
            name = "postgres/${s.database}.dsn";
            value.text = "postgresql://${s.user}@${e.value.dsn.host}:${toString e.value.dsn.port}/${s.database}";
          }) (peers "server" member exports)
        );
      };
  };
}
