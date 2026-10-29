# A clan-style service shipped outside the fleet's modules (as from another flake). It is a function, so the
# importer passes what it needs (clan's importApply). The server exports its address; each client reads it.
{ prefix }:
{ yen, lib, ... }:
let
  member =
    svc: role:
    yen.lib.all [
      yen.kinds.member
      (s: s.service == svc && s.role == role)
    ];
in
{
  yen.helpers.clan.services.borg = {
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
    # nested service: every borg instance adds an sshd instance on its servers
    adds = i: {
      "${prefix}-sshd-for-${i.name}" = {
        module = "sshd";
        roles.server.machines = i.roles.server.machines;
      };
    };
  };
  yen.aspects.borg-server = {
    at = member "borg" "server";
    exports =
      { scope, ... }:
      {
        repo = "borg@${scope.parent.addr}";
        generators.known-host = {
          deploy = [ "web-1" ];
          files."borg.known_hosts".secret = false;
        };
      };
  };
  yen.aspects.borg-client = {
    at = member "borg" "client";
    nixos =
      {
        member,
        scope,
        exports,
        ...
      }:
      let
        servers = yen.helpers.clan.selectExports {
          service = "borg";
          instance = member.instance;
          role = "server";
        } exports;
      in
      {
        services.borgbackup.jobs.${member.instance} = {
          repo = "${(lib.head servers).value.repo}:/srv/${scope.parent.name}";
          paths = [ "/var/lib" ];
          encryption.mode = "none";
          inherit (member.settings) startAt;
        };
      };
  };
}
