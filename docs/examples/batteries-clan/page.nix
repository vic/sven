{
  title = "Clan batteries";
  description = "clan-like service instances: members by name or tag, layered settings, exports, contracts, vars generators and their plan.";
  section = "batteries";
  route = "batteries/clan";
  order = 6;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        [clan](https://clan.lol) describes services as data: a service has roles, an instance places machines in roles by
        name or by tag, each role has typed settings, members export values to each other, and services declare the
        secrets they generate. `yen.lib.batteries.clan` gives the same rules. You keep the words: here the machine kind
        is `machine` and the member kind is `member`.

        | Battery | Value of | Does |
        |---|---|---|
        | `members { instances; services; labelsOf; }` | `spawns.<member kind>` of a machine kind | one member per (instance, role), settings layered: interface default, role, machine |
        | `exports { services; isMember; }` | `reduce` of the exports sink | members write their own key; another scope overrides by key; an unlisted export is an error |
        | `contract { instances; services; machines; labelsOf; }` | `errors` | unknown service or role, no roles, min and max machines per role, `maxInstances` |
        | `settings-typed { services; }` | `errors` at a member | every interface setting is set and has its type |
        | `unknown-tags { instances; machines; labelsOf; }` | a warnings sink | tags that match no machine |
        | `extra-modules` | a class key at a member | the role's `extraModules` |
        | `generators { machineOf; }` | `reduce` of the generators sink | shared generators once, the rest per machine; a missing dependency is an error |
        | `vars-plan { from; machines; recipientsOf; }` | `out` of the generators sink | per machine: secret files with their paths, recipients, generation order |
        | `secret-reads { from; reads; }` | `errors` | an eval-time read of a secret file |
        | `public-value { root; }` | a function | a public var read at eval time, with a default |
      ''
      (docs.file "modules/inventory.nix")
      ''
        Each client reads the server's endpoint from the exports, with its own settings layer:
      ''
      (docs.value result.flake.config)
      ''
        ## Vars
      ''
      (docs.file "modules/vars.nix")
      (docs.value result.flake.varsPlan.web.files)
      ''
        ## The contract

        borg allows one server. A second machine with the `storage` tag makes two:
      ''
      (docs.value (map (e: e.error) (variant "variants/two-servers.nix").errors))
    ];

  checks =
    { result, variant, ... }:
    {
      warnings =
        result.flake.warnings == [ [ "clan: instance daily role client: tag laptops matches no machine" ] ];
      extra-modules = result.flake.config.web.imports == [ { services.borg.verbose = true; } ];
      settings-layers =
        result.flake.config.web.backup.daily.dir == "/srv/backup"
        && result.flake.config.nas.backup.daily.dir == "/var/backup";
      exports = result.flake.config.web.backup.daily.to == [ "nas:22" ];
      vars-plan =
        map (g: g.name) result.flake.varsPlan.web.order == [
          "ssh"
          "borg-daily"
        ]
        && builtins.elem "/run/secrets-for-users/vars/borg-daily/passphrase" (
          map (f: f.path) result.flake.varsPlan.web.files
        );
      public-value =
        result.flake.config.web.sshPub == "ssh-ed25519 AAAAweb"
        && result.flake.config.nas.sshPub == "absent";
      contract =
        map (e: e.error) (variant "variants/two-servers.nix").errors == [
          "clan: instance daily role server: 2 machines, at most 1"
        ];
    };
}
