#: lib.kits.borg :: module -- backup kit: roles client (startAt) and server (1); the server exports its repo address
# A kit shipped as a library module (import it in a fleet). The server exports its address and a known-hosts generator
# for the clients' machines (`deploy` is the clients' `at` predicate); each client reads them from the exports of its
# own assembly. Every borg assembly adds an sshd assembly on its servers. Needs a machine field `addr`.
#   imports = [ inputs.yen.lib.kits.borg ];
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  member =
    role:
    all [
      yen.kinds.member
      (s: same (s.kit or null) yen.kit.borg && s.role == role)
    ];
in
{
  yen.kit.borg = {
    roles = {
      client.interface.startAt = {
        type = lib.types.str;
        default = "daily";
      };
      server = { };
    };
    constraints.roles.server = {
      min = 1;
      max = 1;
    };
    exports = [
      "repo"
      "generators"
    ];
    # a kit that needs another: every borg assembly adds an sshd assembly on its servers
    adds = a: {
      "${a.name}-sshd" = {
        kit = yen.kit.sshd;
        roles.server.at = a.roles.server.at;
      };
    };
  };
  yen.aspects.borg-server = {
    at = member "server";
    exports =
      { scope, ... }:
      {
        repo = "borg@${scope.parent.addr}";
        generators.known-host = {
          deploy = scope.assembly.roles.client.at or [ ];
          files."borg.known_hosts".secret = false;
        };
      };
  };
  yen.aspects.borg-client = {
    at = member "client";
    nixos =
      {
        member,
        scope,
        exports,
        ...
      }:
      let
        servers = lib.filter (e: same e.assembly member.assembly && e.role == "server") exports;
      in
      {
        services.borgbackup.jobs.${member.assembly.name} = {
          repo = "${(lib.head servers).value.repo}:/srv/${scope.parent.name}";
          paths = [ "/var/lib" ];
          encryption.mode = "none";
          inherit (member.settings) startAt;
        };
      };
  };
}
