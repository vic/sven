# NixOS hosts: the nixos sink builds the system; os fans out to nixos (#76).
{ yen, lib, ... }:
let
  inherit (yen.lib) same;
  inherit (yen.lib.reduce) one;
  modlists = (import ./_modlists.nix).checked;
in
{
  # a host on shared pkgs keeps docs off: the manual, man pages and option help differ when pkgs is shared
  yen.aspects.shared-pkgs-no-docs = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.sharedPkgs)
    ];
    nixos.documentation = {
      enable = false;
      nixos.enable = false;
      man.enable = false;
    };
  };
  yen.kinds.host = {
    fields = yen.kinds.machine.fields;
    spawns = {
      user = yen.helpers.usersOn;
      guest = s: lib.filterAttrs (_: g: same g.on s) yen.guest;
    };
    sinks = {
      nixos = {
        # Shared pkgs: hosts with `sharedPkgs` on one (channel, system) reuse the pkgs of the first of them (the leader)
        # through nixpkgs' readOnlyPkgs, so nixpkgs is imported once per group. `nixosConfigurationsOwnPkgs` keeps each
        # follower's build with its own pkgs, so a check can prove both give the same toplevel drvPath.
        out =
          {
            host,
            nixos,
            deploy,
            out,
            ...
          }:
          let
            np = host.channel.nixpkgs;
            # trimmedModules: the host evaluates a smaller base module list (_modlists.nix), in module-list.nix order
            trimmed = host.trimmedModules && modlists ? ${host.name};
            # filter module-list.nix itself: path values stay paths, inline (non-path) entries stay, order stays
            keep = lib.genAttrs (map (
              p: builtins.unsafeDiscardStringContext "${np}/nixos/modules/${p}"
            ) modlists.${host.name}) (_: true); # keys only: attr names hold no context
            base = lib.filter (
              p: !(builtins.isPath p) || keep ? ${builtins.unsafeDiscardStringContext (toString p)}
            ) (import "${np}/nixos/modules/module-list.nix");
            build' =
              full: ms:
              np.lib.nixosSystem (
                {
                  system = host.system.name;
                  modules = ms;
                }
                // lib.optionalAttrs (trimmed && !full) { baseModules = base; }
              );
            build = build' false;
            group = lib.sort (a: b: a < b) (
              lib.attrNames (
                lib.filterAttrs (
                  _: h: h ? addr && h.sharedPkgs && same h.channel host.channel && same h.system host.system
                ) yen.host
              )
            );
            leader = lib.head group;
            follower = host.sharedPkgs && leader != host.name;
            shared = out.nixosConfigurations.${leader}.pkgs;
            readOnly = [
              np.nixosModules.readOnlyPkgs
              { options.nixpkgs.system = np.lib.mkOption { internal = true; }; }
              {
                nixpkgs.pkgs = shared;
                nixpkgs.overlays = np.lib.mkForce shared.overlays;
                nixpkgs.config = np.lib.mkForce shared.config;
              }
            ];
            sys = build (nixos ++ lib.optionals follower readOnly);
          in
          {
            nixosConfigurations.${host.name} = sys;
            nixosConfigurationsOwnPkgs = lib.optionalAttrs follower { ${host.name} = build' true nixos; }; # a reference build: own pkgs, full module list
            nixosConfigurationsFull = lib.optionalAttrs trimmed {
              ${host.name} = build' true (nixos ++ lib.optionals follower readOnly);
            }; # the oracle: same drvPath as the trimmed build
            sharedPkgs = lib.optionalAttrs host.sharedPkgs {
              ${host.name} = {
                inherit leader;
                follower = follower;
              };
            };
            deploy.nodes.${host.name} = {
              hostname = deploy.address;
              sshUser = deploy.user;
            };
            ageManifest.${host.name} = lib.attrNames sys.config.age.secrets;
          };
        colmena =
          {
            host,
            scope,
            nixos,
            deploy,
            tags,
            ...
          }:
          {
            # tags: a source; roles: active aspects (hasAspect = holds)
            ${host.name} = {
              imports = nixos;
              deployment = {
                targetHost = deploy.address;
                tags = [
                  host.environment.name
                ]
                ++ tags
                ++ lib.filter (n: yen.lib.holds yen.aspects."role-${n}" scope) [
                  "server"
                  "workstation"
                  "laptop"
                ];
              };
            };
          };
      };
      os.nixos =
        { os, ... }:
        {
          imports = os;
        };
      deploy.reduce = one;
    };
  };
}
