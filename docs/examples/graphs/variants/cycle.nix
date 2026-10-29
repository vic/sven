# db now depends on lb: a cycle.
{ yen, ... }:
{
  yen.host.db.dependsOn = [ yen.host.lb ];
}
