# secretspec.toml: each feature declares the secrets it needs (values live in a provider, never in git).
# .sops.yaml: each environment of secrets adds its creation rule.
{ yen, ... }:
let
  inherit (yen.lib.batteries) secretspec secrets claim;
in
{
  yen.kinds.repo.sinks = {
    secretspec = {
      reduce = claim { key = s: "${s.profile or "default"}/${s.name}"; }; # one secret, one declaration
      files = secretspec.toml {
        from = yen.kinds.repo.sinks.secretspec;
        project.name = "my-app";
        defaults.providers = [ "keyring" ];
      };
    };
    sops-rules.files = secrets.sops-config { from = yen.kinds.repo.sinks.sops-rules; };
  };
  yen.aspects.database = {
    at = yen.kinds.repo;
    secretspec = {
      name = "DATABASE_URL";
      description = "PostgreSQL connection string";
    };
    sops-rules = {
      path_regex = "secrets/db/.*";
      age = "age1db";
    };
  };
  yen.aspects.database-dev = {
    at = yen.kinds.repo;
    secretspec = {
      name = "DATABASE_URL";
      profile = "development";
      required = false;
      default = "sqlite://./dev.db";
    };
  };
}
