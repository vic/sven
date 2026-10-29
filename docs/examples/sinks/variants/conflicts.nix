# Each line breaks one sink rule.
{ yen, ... }:
{
  yen.aspects.mistakes = {
    at = yen.host.web;
    admin = "bob"; # `one`: two admins
    ports = 70000; # `of`: not a port
    nginx.http.gzip = false; # `merge`: two different leaves at one path
  };
}
