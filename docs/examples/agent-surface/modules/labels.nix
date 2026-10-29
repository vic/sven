# Content gets the trust of the files that declare it: files under agent/ are written by agents.
{ ... }:
{
  yen.labels."agent/" = {
    trust = 1;
  };
}
