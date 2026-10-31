{
  title = "Access kits";
  description = "sshd, users and emergency-access: ready-made kits for who may log in, and the known-hosts battery that lets machines trust each other.";
  section = "batteries";
  route = "batteries/kits-access";
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
        Three kits ship with yen, in `yen.lib.kits`. You import one as a module, then write assemblies of it.
        Each kit needs the fleet's `exports` sink (`kits.exports`) and `generators` sink (`vars.generators`), as below.

        | Kit | Roles | Does |
        |---|---|---|
        | `sshd` | `server`, `client` | a server runs openssh, generates a host key (the private file secret, the public file not) and exports where the public key is; a client gets `programs.ssh.knownHosts` for the servers of its own assembly |
        | `users` | `default` | `user`, `groups`, `shell` (a function from `pkgs` to a package: the fleet has no package ref); a password hash, secret, generated on the machine of that member only |
        | `emergency-access` | `default` | `authorizedKeys` (public keys are data) for root, and a root password hash, secret, on machines that hold a member only |

        `yen.lib.batteries.vars.known-hosts { from; rootOf; entry; keep ? }` is the battery behind the sshd client. It reads the
        public keys with `public-value` and gives two values: `nixos` (the `programs.ssh.knownHosts` records) and
        `errors` (one record for each key file that is missing, never a throw).

        The fleet: machines, the sinks and the contract.
      ''
      (docs.file "modules/fleet.nix")
      ''
        The assemblies. No machine is named by a string: each role's machines are a ref.
      ''
      (docs.file "modules/access.nix")
      ''
        web trusts the key of db, read from `vars/per-machine/db/openssh/ssh.id_ed25519.pub`. db has no known hosts:
      ''
      (docs.value result.flake.nixos.web.programs.ssh)
      (docs.value (result.flake.nixos.db.programs.ssh or null))
      ''
        The secrets are in the plan of the generators, each on one machine:
      ''
      (docs.value (builtins.attrNames result.reduced.generators."fleet:main"))
      ''
        The server settings, and root on db only:
      ''
      (docs.value result.flake.os.db.services.openssh)
      (docs.value result.flake.nixos.db.users.users.root.openssh)
      (docs.value (result.flake.nixos.web.users.users.root or null))
      ''
        ## Errors

        An sshd assembly with no server is a count of zero, and a client alone has nobody to trust:
      ''
      (docs.file "variants/no-server.nix")
      (docs.value (map (e: e.error) (variant "variants/no-server.nix").errors))
      ''
        A server without a public key file is an error record. The fleet still evaluates:
      ''
      (docs.file "variants/missing-key.nix")
      (docs.value (map (e: e.error) (variant "variants/missing-key.nix").errors))
      ''
        One user in two assemblies on one machine:
      ''
      (docs.file "variants/same-user.nix")
      (docs.value (map (e: e.error) (variant "variants/same-user.nix").errors))
    ];

  checks = import ./checks.nix;
}
