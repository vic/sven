# One aspect, two files. `at` is the union of both files.
{ yen, ... }:
{
  yen.aspects.nginx = {
    at = yen.host.web;
    packages = "nginx";
  };
}
