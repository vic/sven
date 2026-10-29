# NixOS batteries. NixOS is the target domain, not a yen word: you write every yen key, a battery is the value.
# A battery that reads a sink takes the sink as a ref (`from`), never its name.
#   yen.kinds.host.sinks.nixos.out = nixos.system { from = yen.kinds.host.sinks.nixos; inherit nixpkgs; };
#   yen.kinds.host.sinks.unfree.nixos = nixos.unfree { from = yen.kinds.host.sinks.unfree; };
#   yen.aspects.hostname = { at = yen.kinds.host; nixos = nixos.hostname; };
{
  # nixosConfigurations.<scope name> from the modules collected in `from`
  system =
    { from, nixpkgs }:
    { scope, sinks, ... }:
    {
      nixosConfigurations.${scope.name} = nixpkgs.lib.nixosSystem { modules = sinks.${from.__sink}; };
    };

  hostname =
    { scope, ... }:
    {
      networking.hostName = scope.name;
    };

  # an account named after the scope (Den's define-user)
  define-user =
    { scope, ... }:
    {
      users.users.${scope.name} = {
        isNormalUser = true;
        home = "/home/${scope.name}";
      };
    };

  # the scope's account administers the machine (Den's primary-user)
  primary-user =
    { scope, ... }:
    {
      users.users.${scope.name}.extraGroups = [
        "wheel"
        "networkmanager"
      ];
    };

  # nixpkgs.config does not merge: allowUnfreePredicate is a function, permittedInsecurePackages loses lists.
  # `from` collects package names; one module allows them.
  unfree =
    { from }:
    { sinks, ... }:
    { lib, ... }:
    {
      nixpkgs.config.allowUnfreePredicate =
        p: lib.elem (lib.getName p) (lib.flatten sinks.${from.__sink});
    };
  insecure =
    { from }:
    { sinks, ... }:
    {
      nixpkgs.config.permittedInsecurePackages = builtins.concatLists sinks.${from.__sink};
    };
}
