# A second, different answer for one leaf. Data never overrides data.
{ yen, ... }:
{
  yen.host.nas.settings.zfs.arcMax = 16;
}
