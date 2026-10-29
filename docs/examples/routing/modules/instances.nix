{ yen, ... }:
{
  yen.environment.prod.public = true;
  yen.environment.lab = { };
  yen.host.web.environment = yen.environment.prod;
  yen.host.box.environment = yen.environment.lab;
  yen.user.alice.on = yen.host.web;
  yen.home.bob.on = yen.host.web;
}
