# age-secrets: one sink name on three kinds. A body that reads `config` is a module element. Unfree names collapse in a set.
{ yen, lib, ... }:
{
  yen.kinds.user.sinks.age-secrets.homeManager =
    { age-secrets, ... }:
    {
      imports = age-secrets;
    };
  yen.kinds.cluster.sinks.age-secrets.k8s-manifests =
    { age-secrets, ... }:
    {
      imports = age-secrets;
    };
  yen.kinds.host.sinks.age-secrets.nixos =
    { age-secrets, ... }:
    {
      imports = age-secrets;
    };
  yen.aspects.attic = {
    at = yen.host.lb;
    age-secrets =
      { config, ... }:
      {
        age.secrets.attic-env = {
          file = ../../secrets/attic.age;
          path = "/run/agenix/${config.networking.hostName}-attic";
        };
      };
  };
  yen.kinds.host.sinks.unfree = {
    of = lib.types.str;
    reduce = yen.lib.reduce.set;
    os =
      { unfree, ... }:
      {
        nixpkgs.config.allowUnfreePredicate = p: lib.elem (lib.getName p) unfree;
      };
  };
  yen.aspects.terraform-cli = {
    at = yen.host.stage;
    unfree = "terraform";
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.terraform ];
      };
  };
}
