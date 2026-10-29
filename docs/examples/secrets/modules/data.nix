{ yen, ... }:
{
  yen.host.web = { };
  yen.host.db = { };
  yen.secret.tls = {
    file = "secrets/tls.age";
    owners = [ yen.host.web ];
  };
  yen.secret.db-password = {
    file = "secrets/db-password.age";
    owners = [
      yen.host.web
      yen.host.db
    ];
  };
}
