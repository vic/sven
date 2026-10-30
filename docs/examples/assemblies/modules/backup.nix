# The backup: an aspect per role, at member scopes. Clients export their address; the server reads them.
{ yen, lib, ... }:
let
  inherit (yen.lib) same;
  role =
    r:
    yen.lib.all [
      yen.kinds.member
      (s: same s.assembly yen.assembly.backup && s.role == r)
    ];
in
{
  yen.aspects.backup-client = {
    at = role "client";
    exports = { host, ... }: host.addr; # published by the member scope: the engine sets `from`
    cycle =
      { tree, ... }:
      let
        nas.scopesOf = yen.host.nas; # a tree request: nas, with its data
        me.nearest = yen.kinds.host; # a tree request: the host this member sits on
      in
      {
        tree = [
          nas
          me
        ];
        config = [
          {
            backup.target = (lib.head (lib.head (tree.select nas))).addr;
            backup.name = (lib.head (tree.select me)).name;
          }
        ];
      };
  };
  yen.aspects.backup-server = {
    at = role "server";
    config =
      { exports, ... }:
      {
        backup.allow = lib.sort (a: b: a < b) (
          map (e: e.value) (lib.filter (e: yen.lib.holds yen.kinds.member e.from) exports)
        );
      };
  };
  # once per machine that takes part in any role of the assembly
  yen.aspects.backup-tools = {
    at = yen.lib.has (s: yen.lib.holds yen.kinds.member s && same s.assembly yen.assembly.backup);
    config.packages = [ "borgbackup" ];
  };
}
