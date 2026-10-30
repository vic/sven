{
  title = "Kits batteries";
  description = "Kits and assemblies: members by `at` predicates, layered settings, exports, contracts, vars generators and their plan.";
  section = "batteries";
  route = "batteries/kits";
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
        A kit is data: it has roles, each role has typed settings, members export values to each other, and kits
        declare the secrets they generate. An assembly is one use of a kit: its `kit` is a ref, and each role takes the
        machines where its `at` predicate holds, the same predicates an aspect uses. `yen.lib.batteries.kits` gives
        the rules. You keep the words: here the machine kind is `machine` and the member kind is `member`.

        | Battery | Value of | Does |
        |---|---|---|
        | `members { assemblies; holds; }` | `spawns.<member kind>` of a machine kind | one member per (assembly, role), with refs to its assembly and kit; settings layered: interface default, then the role's (attrs, or a function of the machine) |
        | `exports { isMember; }` | `reduce` of the exports sink | members write their own entry; another scope overrides an entry by refs; an unlisted export is an error |
        | `contract { assemblies; machines; holds; }` | `errors` | a kit that is no kit, an unknown role, an `at` that is no predicate, no roles, min and max machines per role, `maxAssemblies` |
        | `settings-typed` | `errors` at a member | every interface setting is set and has its type |

        `yen.lib.batteries.vars` gives the secrets that kits generate:

        | Battery | Value of | Does |
        |---|---|---|
        | `generators { machineOf; }` | `reduce` of the generators sink | shared generators once, the rest per machine; a missing dependency is an error |
        | `vars-plan { from; machines; recipientsOf; }` | `out` of the generators sink | per machine: secret files with their paths, recipients, generation order |
        | `secret-reads { from; reads; }` | `errors` | an eval-time read of a secret file |
        | `public-value { root; }` | a function | a public var read at eval time, with a default |
      ''
      (docs.file "modules/inventory.nix")
      ''
        Each client reads the server's endpoint from the exports of its assembly, with its own settings:
      ''
      (docs.value result.flake.config)
      ''
        ## Vars
      ''
      (docs.file "modules/vars.nix")
      (docs.value result.flake.varsPlan.web.files)
      ''
        ## The contract

        borg allows one server. A second machine with `storage` makes two:
      ''
      (docs.value (map (e: e.error) (variant "variants/two-servers.nix").errors))
      ''
        A name is not a ref. A string where the kit goes, and a string where a role's machines go, are errors:
      ''
      (docs.file "variants/by-name.nix")
      (docs.value (map (e: e.error) (variant "variants/by-name.nix").errors))
    ];

  checks =
    {
      result,
      variant,
      eq,
      yes,
      no,
      ...
    }:
    {
      one-assembly-more = {
        t1 = yes (result.flake.config.web.verbose);
        t2 = yes (result.flake.config.nas.verbose);
      };
      settings-layers = {
        t1 = eq (result.flake.config.web.backup.daily.dir) ("/srv/backup");
        t2 = eq (result.flake.config.nas.backup.daily.dir) ("/var/backup");
      };
      exports = eq (result.flake.config.web.backup.daily.to) ([ "nas:22" ]);
      vars-plan = {
        t1 = eq (map (g: g.name) result.flake.varsPlan.web.order) ([
          "ssh"
          "borg-daily"
        ]);
        t2 = yes (
          builtins.elem "/run/secrets-for-users/vars/borg-daily/passphrase" (
            map (f: f.path) result.flake.varsPlan.web.files
          )
        );
      };
      public-value = {
        t1 = eq (result.flake.config.web.sshPub) ("ssh-ed25519 AAAAweb");
        t2 = eq (result.flake.config.nas.sshPub) ("absent");
      };
      contract = eq (map (e: e.error) (variant "variants/two-servers.nix").errors) ([
        "kits: assembly daily role server: 2 machines, at most 1"
      ]);
      by-name =
        let
          es = map (e: e.error) (variant "variants/by-name.nix").errors;
        in
        {
          t1 = yes (builtins.elem "kits: assembly hourly role server: `at` is a string, not a predicate" es);
          t2 = yes (builtins.any (e: builtins.match ".*kit.*string.*|.*string.*kit.*" e != null) es);
        };
    };
}
