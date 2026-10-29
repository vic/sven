# NixOS batteries: generic batteries filled with NixOS option paths. NixOS is the target domain, not a yen word:
# every yen name (kind, sink, aspect) is the key you write.
#   yen.kinds.host.sinks = nixos.system { as = "nixos"; inherit nixpkgs; } // nixos.unfree { as = "unfree"; into = "nixos"; };
#   yen.aspects.hostname = nixos.hostname { at = yen.kinds.host; into = "nixos"; };
let
  bat = import ./generic.nix;
  # an aspect whose `into` content is a NixOS module built from the scope
  scoped =
    body:
    { at, into }:
    bat.gated { inherit at into body; };
  # sinks: names collected in `as`, one module of `into` built from them
  names =
    module:
    { as, into }:
    bat.pool {
      inherit as into;
      set = ns: module (builtins.concatLists ns);
    };
in
{
  # sinks: nixosConfigurations.<scope name> from the modules of sink `as`
  system =
    { as, nixpkgs }:
    bat.system {
      inherit as;
      out = s: modules: { nixosConfigurations.${s.name} = nixpkgs.lib.nixosSystem { inherit modules; }; };
    };

  hostname = scoped (s: {
    networking.hostName = s.name;
  });

  # an account named after the scope (Den's define-user)
  define-user = scoped (s: {
    users.users.${s.name} = {
      isNormalUser = true;
      home = "/home/${s.name}";
    };
  });

  # the scope's account administers the machine (Den's primary-user)
  primary-user = scoped (s: {
    users.users.${s.name}.extraGroups = [
      "wheel"
      "networkmanager"
    ];
  });

  # nixpkgs.config does not merge: allowUnfreePredicate is a function, permittedInsecurePackages loses lists.
  unfree = names (
    ns:
    { lib, ... }:
    {
      nixpkgs.config.allowUnfreePredicate = p: lib.elem (lib.getName p) ns;
    }
  );
  insecure = names (ns: {
    nixpkgs.config.permittedInsecurePackages = ns;
  });
}
