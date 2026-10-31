# a database user that is a number, and a cache server with a port that is no port
{ yen, ... }:
{
  yen.assembly = {
    db3 = {
      kit = yen.kit.postgres;
      roles = {
        server.at = yen.host.nas;
        client = {
          at = yen.host.web;
          settings = {
            database = "d";
            user = 42;
          };
        };
      };
    };
    cache3 = {
      kit = yen.kit.nix-cache;
      roles.server = {
        at = yen.host.nas;
        settings.port = 70000;
      };
    };
  };
}
