# vars, the configuration half: kits declare generators; generation itself is a tool, not yen.
# A shared generator is one for all machines that use it; a per-machine one is keyed by machine. A dependency must
# name a generator the same machine has (or a shared one). A null element gives nothing. The plan per machine
# (paths by `neededFor`, generation order) is data. Public values are read at eval time from the repo, with a
# default; a read of a secret file is an error. Machines come from directories too.
{ yen, lib, ... }:
let
  inherit (yen.lib)
    all
    opt
    maybe
    same
    ;
  machineOf = s: if yen.lib.holds yen.kinds.member s then s.parent else s;
  machineNames = lib.attrNames yen.host ++ lib.attrNames yen.mac;
in
{
  yen.kinds.fleet.sinks.generators = {
    reduce = yen.lib.batteries.vars.generators { inherit machineOf; };
    # the plan per machine: secret files with their path, and the order to generate in (dependencies first)
    out = yen.lib.batteries.vars.vars-plan {
      from = yen.kinds.fleet.sinks.generators;
      machines = machineNames;
      recipientsOf =
        m:
        let
          r = yen.fleet.main.recipients;
        in
        r.hosts.${m} or r.default; # a host list replaces the default, never adds to it
    };
  };
  yen.kinds.fleet.sinks.public-reads.reduce = yen.lib.reduce.entries;
  yen.kinds.fleet.fields.secretStore = opt (yen.helpers.enum [
    "sops"
    "age"
    "password-store"
  ]) "sops";
  yen.kinds.fleet.fields.recipients = opt (yen.lib.is lib.isAttrs) {
    default = [ ];
    hosts = { };
  };
  yen.fleet.main.recipients = {
    default = [ "age1admin" ];
    hosts.lb = [
      "age1lb"
      "age1admin"
    ];
  };
  yen.kinds.machine.fields.fromDir = opt lib.types.bool false; # a host from a directory under machines/
  yen.kinds.machine.fields.secretStore = maybe (
    yen.helpers.enum [
      "sops"
      "age"
      "password-store"
    ]
  );
  yen.aspects.vars-secret-reads = {
    at = yen.kinds.fleet;
    errors = yen.lib.batteries.vars.secret-reads {
      from = yen.kinds.fleet.sinks.generators;
      reads = yen.kinds.fleet.sinks.public-reads;
    };
  };
  yen.aspects.vars-guard = {
    at = yen.kinds.fleet;
    errors =
      { fleet, generators, ... }:
      map (m: "vars: ${m.name} uses secret store ${m.secretStore}, the fleet uses ${fleet.secretStore}") (
        lib.filter (m: m.secretStore != null && m.secretStore != fleet.secretStore) (
          lib.attrValues yen.host ++ lib.attrValues yen.mac
        )
      )
      ++ lib.concatMap (
        g:
        lib.optional (
          lib.any (m: yen.mac ? ${m}) g.machines
          && lib.any (d: d ? restartUnits) (lib.attrValues (g.files or { }))
        ) "vars: ${g.name}: restartUnits is NixOS only, a darwin machine uses it"
      ) (lib.attrValues generators);
  };

  # the openssh host key generator is part of the sshd kit (lib/kits/sshd.nix)
  yen.aspects.vars-wifi = {
    at = all [
      yen.kinds.member
      (s: same (s.kit or null) yen.kit.wifi)
    ];
    generators = {
      name = "wifi.home";
      share = true;
      files = {
        password.secret = true;
        ca-key = {
          secret = true;
          deploy = false;
        };
      };
    };
  };
  yen.aspects.vars-borg = {
    at = all [
      yen.kinds.member
      (s: same (s.kit or null) yen.kit.borg && s.role == "client")
    ];
    generators =
      { member, ... }:
      {
        name = "borg-${member.assembly.name}";
        dependencies = [ "openssh" ];
        files.passphrase = {
          secret = true;
          neededFor = "users";
          restartUnits = [ "borgbackup-job-${member.assembly.name}.service" ];
        };
      };
  };
  # generators carried by an export: each machine in an export's `deploy` list gets them
  yen.aspects.vars-from-exports = {
    at = yen.helpers.machines;
    generators =
      { scope, exports, ... }:
      let
        gens = lib.concatMap (
          x: lib.filter (g: yen.lib.holds g.deploy scope) (lib.attrValues (x.value.generators or { }))
        ) exports;
      in
      if gens == [ ] then
        null
      else
        {
          name = "from-exports";
          files = lib.foldl' (a: g: a // g.files) { } gens;
        };
  };

  # machines from directories: every directory under machines/ is a host; its configuration.nix joins the config
  yen.host = lib.mapAttrs (_: _: { fromDir = true; }) (
    lib.filterAttrs (_: t: t == "directory") (builtins.readDir ../../machines)
  );
  yen.aspects.autoinclude = {
    at = all [
      yen.kinds.host
      (s: builtins.pathExists (../../machines + "/${s.name}/configuration.nix"))
    ];
    nixos =
      { host, ... }:
      {
        imports = [ (../../machines + "/${host.name}/configuration.nix") ];
      };
  };
}
