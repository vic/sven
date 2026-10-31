# Hosts with `sharedPkgs` reuse the pkgs of the first sharing host (the leader): nixpkgs is imported once.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  np = inputs.nixpkgs;
in
{
  yen.kinds.fleet = {
    spawns.host = _: yen.host;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  # the sharing hosts, at the fleet: a host reads its group through this sink, so the read is an edge
  yen.kinds.fleet.sinks.shared-pkgs.reduce = yen.lib.reduce.entries;
  yen.aspects.shared-pkgs = {
    at = yen.lib.all [
      yen.kinds.host
      (s: s.sharedPkgs)
    ];
    shared-pkgs = { host, ... }: host.name;
  };
  yen.kinds.host = {
    fields = {
      system = yen.lib.opt lib.types.str "x86_64-linux";
      sharedPkgs = yen.lib.opt lib.types.bool false;
    };
    sinks.nixos.out =
      {
        host,
        nixos,
        out,
        shared-pkgs,
        ...
      }:
      let
        group = lib.sort (a: b: a < b) (
          map (e: e.from.name) (lib.filter (e: e.from.system == host.system) shared-pkgs)
        ); # one group per system: `system` is data, so `==`; `same` compares refs only
        leader = lib.head group;
        follower = host.sharedPkgs && leader != host.name;
        shared = out.nixosConfigurations.${leader}.pkgs; # the `out` arg: the leader's built pkgs, lazily
        readOnly = [
          np.nixosModules.readOnlyPkgs
          { options.nixpkgs.system = lib.mkOption { internal = true; }; }
          { nixpkgs.pkgs = shared; }
        ];
      in
      {
        nixosConfigurations.${host.name} = np.lib.nixosSystem {
          inherit (host) system;
          modules = nixos ++ lib.optionals follower readOnly;
        };
        sharedLeader.${host.name} = if follower then leader else null; # whose pkgs this host reuses
        ownPkgs.${host.name} = np.lib.nixosSystem {
          inherit (host) system;
          modules = nixos;
        }; # the oracle: the same host with its own pkgs
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
