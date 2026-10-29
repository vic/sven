{ yen, ... }:
{
  yen.aspects.nginx = {
    at = yen.host.db;
    packages = { host, ... }: "nginx-conf-${host.name}"; # a function under the same key: one more element
  };
}
