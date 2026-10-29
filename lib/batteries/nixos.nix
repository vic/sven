# NixOS batteries: generic batteries filled with NixOS option paths. NixOS is the target domain, not a yen word:
# every yen name (kind, sink, aspect) still comes from the user.
let
  bat = import ./generic.nix;
in
{
  # nixosConfigurations.<scope name> from the modules of sink `as`
  system =
    {
      kind,
      as,
      nixpkgs,
    }:
    bat.system {
      inherit kind as;
      out = s: modules: { nixosConfigurations.${s.name} = nixpkgs.lib.nixosSystem { inherit modules; }; };
    };

  # networking.hostName = the scope name
  hostname =
    {
      name,
      at,
      into,
    }:
    bat.gated {
      inherit name at into;
      body = s: { networking.hostName = s.name; };
    };

  # an account named after the scope (Den's define-user)
  define-user =
    {
      name,
      at,
      into,
    }:
    bat.gated {
      inherit name at into;
      body = s: {
        users.users.${s.name} = {
          isNormalUser = true;
          home = "/home/${s.name}";
        };
      };
    };

  # the scope's account administers the machine (Den's primary-user)
  primary-user =
    {
      name,
      at,
      into,
    }:
    bat.gated {
      inherit name at into;
      body = s: {
        users.users.${s.name}.extraGroups = [
          "wheel"
          "networkmanager"
        ];
      };
    };

  # nixpkgs.config does not merge: allowUnfreePredicate is a function, permittedInsecurePackages loses lists.
  # A pool of names, one module per scope.
  unfree =
    {
      on,
      as,
      into,
    }:
    bat.pool {
      inherit on as into;
      set =
        names:
        { lib, ... }:
        {
          nixpkgs.config.allowUnfreePredicate = p: lib.elem (lib.getName p) (lib.flatten names);
        };
    };
  insecure =
    {
      on,
      as,
      into,
    }:
    bat.pool {
      inherit on as into;
      set =
        names:
        { lib, ... }:
        {
          nixpkgs.config.permittedInsecurePackages = lib.flatten names;
        };
    };
}
