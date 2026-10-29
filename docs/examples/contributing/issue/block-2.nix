# The problem: two aspects give an admin. I expected the second to win.
{ yen, ... }:
{
  yen.aspects.ops = {
    at = yen.kinds.host;
    admin = "ana";
  };
  yen.aspects.dev = {
    at = yen.host.web;
    admin = "bo";
  };
}
