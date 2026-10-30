# a database with a client and no machine for the server role
{ yen, ... }:
{
  yen.assembly.db2 = {
    kit = yen.kit.postgres;
    roles = {
      server.at = _: false;
      client = {
        at = yen.host.web;
        settings = {
          database = "d";
          user = "u";
        };
      };
    };
  };
}
