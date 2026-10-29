# den-hoag class-share (A18) as a capability: the config every member of a class shares is computed ONCE (the core),
# each member keeps only its delta, and a gate proves the shared build equals the full build (same toplevel drvPath).
# The core is the elements equal at every member. A function element is never equal to another (Nix `==`), so
# config-dependent content stays in the deltas, as den-hoag's `classInvariant` projection does.
{ yen, lib, ... }:
let
  inherit (yen.lib.reduce) entries;
in
{
  yen.kinds.fleet.sinks.class-members.reduce = entries;
  yen.kinds.host.sinks.nixos.class-members =
    { host, nixos, ... }:
    {
      name = host.name;
      modules = nixos;
      inherit (host) channel system minimal;
    };
  yen.aspects.class-share = {
    at = yen.fleet.main;
    out =
      { class-members, out, ... }:
      let
        members = lib.filter (m: !m.minimal) (map (e: e.value) class-members);
        core = lib.foldl' (acc: m: lib.filter (v: lib.elem v m.modules) acc) (lib.head members).modules (
          lib.tail members
        );
        delta = m: lib.filter (v: !(lib.elem v core)) m.modules;
        shared =
          m:
          m.channel.nixpkgs.lib.nixosSystem {
            system = m.system.name;
            modules = [ { imports = core; } ] ++ delta m;
          };
        gate =
          m:
          (shared m).config.system.build.toplevel.drvPath
          == out.nixosConfigurations.${m.name}.config.system.build.toplevel.drvPath;
      in
      {
        classShare.nixos = {
          inherit core;
          coreSize = lib.length core;
          members = lib.listToAttrs (
            map (
              m:
              lib.nameValuePair m.name {
                delta = delta m;
                deltaSize = lib.length (delta m);
                fullSize = lib.length m.modules;
                gate = gate m;
              }
            ) members
          );
        };
      };
  };
}
