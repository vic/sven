{ yen, ... }:
{
  yen.environment.prod = { };
  yen.environment.lab = { };
  yen.host.web.environment = yen.environment.prod;
  yen.host.db.environment = yen.environment.prod;
  yen.host.box.environment = yen.environment.lab;
  yen.user.alice.hosts = [
    yen.host.web
    yen.host.box
  ]; # one user, two scopes
  yen.user.bob.hosts = [ yen.host.db ];
}
