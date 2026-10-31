# A channel that is not in the list, and a label that is not a string.
{ yen, ... }:
{
  yen.host.cache = {
    addr = "10.0.0.3";
    settings.kernel.channel = "stable";
    labels.owner = 1;
  };
}
