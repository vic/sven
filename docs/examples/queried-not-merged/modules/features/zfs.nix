# Each feature declares its own setting, at its own path, in its own file.
{ yen, lib, ... }:
{
  yen.kinds.host.fields.settings.zfs.arcMax = yen.lib.maybe lib.types.int;
  yen.kinds.environment.fields.settings.zfs.arcMax = yen.lib.maybe lib.types.int;
}
