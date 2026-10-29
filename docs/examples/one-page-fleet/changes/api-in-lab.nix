# A change, as an agent proposes it: a lab host that uses the prod database.
{ yen, ... }:
{
  yen.host.api = {
    env = yen.env.lab;
    addr = "10.0.1.2";
    db = yen.host.db;
  };
}
