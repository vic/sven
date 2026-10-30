{
  title = "Environments";
  description = "prod and staging: hosts grouped by where they run, settings that cascade, and access from groups.";
  section = "recipes";
  order = 2;

  body =
    { docs, result, ... }:
    [
      ''
        An environment owns its hosts. It gives them a domain and default settings, and it decides which people
        may log in. staging inherits from prod what it does not set.
      ''
      (docs.fileWith "{23,28}" "modules/kinds.nix")
      (docs.file "modules/data.nix")
      ''
        Users are not listed per host. A user lives on a host when one of their groups is in the environment's `grants`:
      ''
      (docs.scopes result)
      ''
        ## Settings cascade

        `yen.lib.cascade` takes the first value along host, environment, base environment:
      ''
      (docs.fileWith "{6-9}" "modules/base.nix")
      (docs.value result.flake.timeZones)
      (docs.tip "Promote a host" ''
        Move `web-next` to prod with one edit: `environment = yen.environment.prod`. Its domain, its time zone default
        and its users follow from the data.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      zones = eq (result.flake.timeZones) ({
        api-next = "UTC";
        web = "UTC";
        web-next = "Europe/Berlin";
      });
      access = eq (builtins.length (builtins.filter (s: s.name == "dev") result.scopes)) (2);
    };
  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    {
      domain = eq (flake.nixosConfigurations.api-next.config.networking.fqdn) (
        "api-next.staging.example.com"
      );
      tz = eq (flake.nixosConfigurations.api-next.config.time.timeZone) ("UTC");
    };
}
