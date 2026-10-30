# Content gets the trust of the files that declare it: files under agent/ are written by agents. Label your own files
# too: content that no label covers has trust 0.
{ ... }:
{
  yen.labels = {
    "modules/".trust = 3;
    "agent/".trust = 1;
  };
}
