# clan vars: generators declared by services, a plan per machine, public values read at eval time.
{ yen, lib, ... }:
let
  clan = yen.lib.batteries.clan;
  machineOf = s: if yen.lib.holds yen.kinds.member s then s.parent else s;
in
{
  yen.kinds.fleet.sinks = {
    generators = {
      reduce = clan.generators { inherit machineOf; };
      out = clan.vars-plan {
        from = yen.kinds.fleet.sinks.generators;
        machines = lib.attrNames yen.machine;
        recipientsOf = m: [ "age1admin" ];
      };
    };
    public-reads.reduce = yen.lib.reduce.entries;
  };
  yen.aspects.ssh-vars = {
    at = yen.kinds.machine;
    # a function of the scope: one per machine (static content goes once per receiver)
    generators =
      { scope, ... }:
      {
        name = "ssh";
        files.key.secret = true;
        files."key.pub".secret = false;
      };
    config =
      { scope, ... }:
      {
        sshPub = clan.public-value { root = ../vars/per-machine; } scope.name "ssh" "key.pub" "absent";
      };
  };
  yen.aspects.borg-vars = {
    at = yen.lib.all [
      yen.kinds.member
      (s: s.service == "borg" && s.role == "client")
    ];
    generators =
      { scope, ... }:
      {
        name = "borg-${scope.instance}";
        dependencies = [ "ssh" ];
        files.passphrase.neededFor = "users";
      };
  };
  yen.aspects.secret-reads = {
    at = yen.kinds.fleet;
    errors = clan.secret-reads {
      from = yen.kinds.fleet.sinks.generators;
      reads = yen.kinds.fleet.sinks.public-reads;
    };
  };
}
