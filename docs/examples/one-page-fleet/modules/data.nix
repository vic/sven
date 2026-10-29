# Instances: plain data, refs between them.
{ yen, ... }:
{
  yen.fleet.main = { };
  yen.env.prod.domain = "example.com";
  yen.env.lab.domain = "lab.example.com";
  yen.host.web = {
    env = yen.env.prod;
    db = yen.host.db;
  };
  yen.host.db.env = yen.env.prod;
  yen.host.box.env = yen.env.lab;
  yen.user.ana.on = [
    yen.host.web
    yen.host.box
  ];
}
