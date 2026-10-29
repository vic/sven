# A second file gives the same helper. Functions are never equal, so this is two answers, not an override.
{ yen, ... }:
{
  yen.helpers.k3sRole = host: "server";
}
