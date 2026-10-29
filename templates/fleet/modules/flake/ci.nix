# CI from the fleet itself: every buildable config gives one job. `ci.json` is a generated file, so its check fails when the infra changes and nobody regenerated it.
{ yen, lib, ... }:
let
  job = system: name: attr: { ${name} = { inherit name attr system; }; };
in
{
  yen.kinds.fleet.sinks.ci = {
    reduce = yen.lib.reduce.merge;
    out =
      { ci, ... }:
      {
        ci.matrix = lib.attrValues ci;
      };
  };
  yen.aspects.ci-host = {
    at = yen.lib.all [
      yen.kinds.host
      (s: !s.minimal)
    ];
    ci =
      { host, ... }:
      job host.system.name host.name "nixosConfigurations.${host.name}.config.system.build.toplevel";
  };
  yen.aspects.ci-mac = {
    at = yen.kinds.mac;
    ci =
      { mac, ... }:
      job mac.system.name mac.name "darwinConfigurations.${mac.name}.config.system.build.toplevel";
  };
  yen.aspects.ci-home = {
    at = yen.kinds.home;
    ci =
      { home, ... }:
      job home.system.name home.name "homeConfigurations.\"${home.name}\".activationPackage";
  };
  yen.aspects.ci-shell = {
    at = yen.kinds.system;
    ci = { system, ... }: job system.name "devshell-${system.name}" "devShells.${system.name}.default";
  };
  yen.aspects.ci-file = {
    at = yen.system.x86_64-linux;
    files =
      { ci, ... }:
      {
        files.file."ci.json".text = builtins.toJSON (lib.attrValues ci) + "\n";
      };
  };
}
