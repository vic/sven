# `yen.helpers`: shared values and functions. Any file declares a key; any module reads it from `yen`.
{ yen, ... }:
{
  yen.helpers.k3sRole = host: host.settings.k3s.role;
}
