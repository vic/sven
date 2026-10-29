# A secret by name, not by ref: `of` refuses it.
{ yen, ... }:
{
  yen.aspects.shortcut = {
    at = yen.host.db;
    secrets = "tls";
  };
}
