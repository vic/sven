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
        ...
      }:
      let
        group = lib.sort (a: b: a < b) (
          lib.attrNames (lib.filterAttrs (_: h: h.sharedPkgs && h.system == host.system) yen.host)
        ); # one group per system
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
        ownPkgs.${host.name} = np.lib.nixosSystem {
          inherit (host) system;
          modules = nixos;
        }; # the oracle: the same host with its own pkgs
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
