# Tags from active roles: `yen.lib.holds` asks an aspect at a scope. A deploy tool can read them.
{ yen, lib, ... }:
{
  yen.aspects.tags = {
    at = yen.kinds.host;
    out =
      { host, scope, ... }:
      {
        tags.${host.name} = lib.filter (r: yen.lib.holds yen.aspects.${r} scope) [
          "server"
          "workstation"
          "laptop"
          "nvidia"
          "ci-runner"
          "gaming"
          "backups"
        ];
      };
  };
}
