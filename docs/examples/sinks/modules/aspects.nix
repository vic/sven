{ yen, ... }:
{
  yen.aspects.base = {
    at = yen.kinds.host;
    motd = "welcome";
    ports = 22;
    admin = "alice";
    nginx.http.gzip = true;
    owners = "ops";
    groups = "wheel";
  };
  yen.aspects.web = {
    at = yen.host.web;
    motd = "this host serves web";
    ports = 22; # a duplicate: `set` keeps one
    nginx.http.servers.www.port = 80; # `merge` joins the attrsets
    groups = "audio";
  };
}
