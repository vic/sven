# A typo in a field name, and a string where an int goes.
{ yen, ... }:
{
  yen.host.cache = {
    adr = "10.0.0.3";
    cores = "8";
  };
}
