# Broadcast to the same user elsewhere, and to a hub, with a transform (syncthing-peers, replicateHome).
{ yen, lib, ... }:
let
  inherit (yen.lib) all within same;
in
{
  yen.kinds.fleet.sinks = {
    syncthing-peers.reduce = yen.lib.reduce.entries;
    replicate-home.reduce = yen.lib.reduce.entries;
  };
  yen.kinds.machine.fields.settings.syncthing.isHub = yen.lib.opt lib.types.bool false;
  yen.host.stage.settings.syncthing.isHub = true;
  yen.aspects.syncthing-peer = {
    at = all [
      yen.kinds.user
      (within yen.helpers.linux)
    ];
    syncthing-peers =
      { scope, ... }:
      {
        id = builtins.hashString "sha256" scope.parent.name;
      };
    replicate-home =
      { user, ... }:
      {
        inherit user;
        directories = [ "Documents" ];
      };
    homeManager =
      {
        syncthing-peers,
        user,
        scope,
        ...
      }:
      {
        home.file.".syncthing-peers".text = builtins.toJSON (
          map (e: e.from.parent.name) (
            lib.filter (e: same e.from user && e.from.path != scope.path) syncthing-peers
          )
        );
      };
  };
  yen.aspects.syncthing-hub = {
    at = all [
      yen.kinds.host
      (s: s.settings.syncthing.isHub)
    ];
    nixos =
      { replicate-home, ... }:
      {
        services.syncthing.settings.folders = lib.listToAttrs (
          map (
            e: lib.nameValuePair "${e.value.user.name}-home" { path = "/srv/${e.value.user.name}"; }
          ) replicate-home
        );
      };
  };
}
