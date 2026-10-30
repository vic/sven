#: lib.kits.sshd :: { yen, lib, ... } -> module -- kit sshd: servers run openssh and export a host key, clients trust the servers of their own assembly
# roles: `server` (at least one per assembly) enables services.openssh, generates the host key (the private file
# secret, the public file not) and exports where the public key is; `client` (setting `root`, an absolute path: the vars directory
# to read public keys from) gets programs.ssh.knownHosts for the servers of its own assembly, and an error when
# the assembly has no server. Needs the fleet's `exports` sink (kits.exports) and `generators` sink (vars.generators).
#   imports = [ inputs.yen.lib.kits.sshd ];
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  kit = yen.kit.sshd;
  member =
    role:
    all [
      yen.kinds.member
      (s: same (s.kit or null) kit && s.role == role)
    ];
  servers = scope: e: same e.assembly scope.assembly && e.role == "server";
  trust = yen.lib.batteries.vars.known-hosts {
    from = yen.kinds.fleet.sinks.exports;
    rootOf = s: s.settings.root;
    keep = servers;
    entry =
      e:
      if e.value ? hostKey then
        {
          host = e.machine.name;
          machine = e.machine.name;
          inherit (e.value.hostKey) generator file;
        }
      else
        null;
  };
in
{
  yen.kit.sshd = {
    roles = {
      server = { };
      client.interface.root.type = lib.types.path;
    };
    constraints.roles.server.min = 1;
    exports = [ "hostKey" ];
  };

  yen.aspects.kit-sshd-server = {
    at = member "server";
    os.services.openssh.enable = true;
    generators =
      { member, ... }:
      {
        name = "openssh";
        files = {
          "ssh.id_ed25519".secret = true;
          "ssh.id_ed25519.pub".secret = false;
        };
      }; # a function: one per machine (static content goes once per receiver)
    exports =
      { member, ... }: # `member` is no dead binding: the engine reads the arg names
      {
        hostKey = {
          generator = "openssh";
          file = "ssh.id_ed25519.pub";
        };
      };
  };

  yen.aspects.kit-sshd-client = {
    at = member "client";
    inherit (trust) nixos;
    errors =
      {
        scope,
        sinks,
        exports,
        ...
      }@args:
      trust.errors args
      ++ lib.optional (
        !lib.any (servers scope) exports
      ) "sshd: ${scope.assembly.name}.client has no server in its assembly";
  };
}
