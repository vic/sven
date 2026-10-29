# Den #525 (a policy gated on hasAspect that creates structure): a backup job scope exists under every host where the
# `role-server` aspect holds. Structure reads presence at the parent; presence never reads the structure it makes.
{ yen, lib, ... }:
{
  yen.kinds.host.spawns.backup =
    s: lib.optionalAttrs (yen.lib.holds yen.aspects.role-server s) { nightly = { }; };
  yen.kinds.backup.sinks.nixos.nixos =
    {
      backup,
      host,
      nixos,
      ...
    }:
    {
      services.restic.backups.${backup.name} = {
        paths = lib.concatMap (m: m.paths or [ ]) nixos;
        repository = "sftp:backup@10.0.9.9:/srv/${host.name}";
        passwordFile = "/run/agenix/restic";
      };
    };
  yen.aspects.backup-persist = {
    at = yen.kinds.backup;
    nixos =
      { host, ... }:
      {
        paths = [
          "/persist"
          "/etc/${host.name}"
        ];
      };
  };
}
