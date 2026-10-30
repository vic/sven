# Environments own hosts, macs and phones (parent-side spawns) and two pools.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.helpers) listOf inEnv enum;
  inherit (yen.lib) opt maybe;
in
{
  yen.kinds.environment = {
    fields = {
      grants = listOf yen.kinds.group;
      edge = opt lib.types.bool false;
      base = maybe yen.kinds.environment;
      settings.kernel.channel = maybe (enum [
        "lts"
        "latest"
      ]);
    };
    spawns = {
      host = inEnv yen.host;
      mac = inEnv yen.mac;
      phone = inEnv yen.phone;
    };
    sinks.backends.of = lib.types.str; # lb reads it
    sinks.terraform = {
      # a conditional receiver
      at = s: s.edge;
      out = yen.lib.batteries.terranix.configuration {
        from = yen.kinds.environment.sinks.terraform;
        inherit (inputs.terranix.lib) terranixConfiguration;
        system = "x86_64-linux";
        name = _: "dns";
      };
    };
  };
  yen.environment.prod = {
    grants = [
      yen.group.admin
      yen.group.sso
    ];
    edge = true;
    settings.kernel.channel = "lts";
  };
  yen.environment.staging = {
    grants = [
      yen.group.admin
      yen.group.deploy
    ];
    base = yen.environment.prod;
  };
  yen.environment.lab = {
    grants = [ ];
  }; # apps for the shared-pkgs comparison: no users, no edge
}
