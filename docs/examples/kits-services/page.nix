{
  title = "Kits of the library";
  description = "Ready-made kits for backups, wifi, remote builders, a binary cache, monitoring and postgres: the fleet writes only assemblies.";
  section = "batteries";
  route = "batteries/kits-services";
  order = 5;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        `yen.lib.kits` holds ready-made kits. A kit is a module: you import it, then write an assembly that puts your
        machines in its roles. The kit has the roles, the typed interface, the limits, the exports and the aspects.
        Each client reads what the servers of its own assembly export, never another assembly's.

        | Kit | Roles | Server exports | Client does |
        |---|---|---|---|
        | `borg` | `client`, `server` (1) | `repo`, a known-hosts generator for the clients | `services.borgbackup.jobs` |
        | `wifi` | `default` with `networks` | | `/etc/wifi/networks`; one secret file `psk.<network>` in a generator shared by all machines of the role |
        | `remote-builders` | `builder` (1 or more), `client` | `host`, `systems`, `speedFactor` | `nix.buildMachines`, with the battery `nixos.remote-builders` |
        | `nix-cache` | `server` (1), `client` | `url`, `key` (the ref of the generated `cache-key.pub`); a signing-key generator; harmonia with the `cache-key.pem` path | `nix.settings.substituters` and `trusted-public-keys`, read from the public var |
        | `monitoring` | `server` (1), `exporter` | exporter: `target` | server: `services.prometheus.scrapeConfigs`, one job per exporter |
        | `postgres` | `server` (1), `client` with `database`, `user` | `dsn` | server: the roles and databases, listens, one `pg_hba` line per client of its own assembly; client: its connection string |

        The kits need a machine field `addr`. `nix-cache` takes `{ root; }`, the vars directory the public key is read from. The fleet writes only the assemblies:
      ''
      (docs.file "modules/assemblies.nix")
      ''
        The sinks and the contract are the fleet's words, the same as in the kits battery page:
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## The result

        The web host builds on the nas, uses its cache, runs the node exporter and the borg job:
      ''
      (docs.value result.flake.config.web)
      ''
        The monitoring server reads one scrape job per exporter of its assembly:
      ''
      (docs.value result.flake.config.lb.services.prometheus.scrapeConfigs)
      ''
        The secrets the kits generate, as the vars plan of the nas:
      ''
      (docs.value result.flake.varsPlan.nas.files)
      ''
        ## The contract

        nix-cache allows one server. A cache with two:
      ''
      (docs.file "variants/two-servers.nix")
      (docs.value (map (e: e.error) (variant "variants/two-servers.nix").errors))
      ''
        A database with a client and no machine for the server role:
      ''
      (docs.file "variants/no-server.nix")
      (docs.value (map (e: e.error) (variant "variants/no-server.nix").errors))
      ''
        A setting of the wrong type, and a port that is no port:
      ''
      (docs.file "variants/wrong-type.nix")
      (docs.value (map (e: e.error) (variant "variants/wrong-type.nix").errors))
      ''
        A cache whose server has no generated public key in the vars directory is an error, never a key "absent":
      ''
      (docs.file "variants/no-key.nix")
      (docs.value (map (e: e.error) (variant "variants/no-key.nix").errors))
    ];

  checks = import ./checks.nix;
}
