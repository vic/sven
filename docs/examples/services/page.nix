{
  title = "Services and roles";
  description = "Service instances as data: each machine gets one member scope per role, and members exchange data.";
  section = "recipes";
  order = 8;
  badge = "advanced";

  body =
    { docs, r, ... }:
    [
      ''
        A service such as backup has roles: one server, many clients. The instance says which machine takes which role.
        This is [clan](https://clan.lol)'s inventory model, in plain yen.
      ''
      (docs.file "modules/inventory.nix")
      ''
        Each machine spawns one `member` scope per (instance, role) it takes part in. An aspect at a member scope runs once
        per instance (clan's `perInstance`). An aspect at a machine that `has` a member runs once per machine (`perMachine`).
      ''
      (docs.fileWith "{5-7,23}" "modules/kinds.nix")
      (docs.scopes r)
      ''
        ## Members exchange data

        Clients publish their address to a fleet sink with `entries`. The engine sets `from`, so a member can only publish
        as itself. The server reads the entries and builds its allow list:
      ''
      (docs.fileWith "{9,14}" "modules/backup.nix")
      (docs.value r.flake.config)
      (docs.tip "The full model" ''
        The [reference fleet](https://github.com/vic/yen/blob/main/templates/fleet/modules/clan/inventory.nix) adds tags as role members,
        typed role settings with errors, exports per service with owner overrides, install order, and vars generators.
      '')
    ];

  checks =
    { r, ... }:
    {
      allow =
        r.flake.config.nas.backup.allow == [
          "10.0.0.1"
          "10.0.0.2"
        ];
      members =
        map (s: s.id) (builtins.filter (s: s.kind == "member") r.scopes) == [
          "fleet:main/host:db/member:backup.client"
          "fleet:main/host:nas/member:backup.server"
          "fleet:main/host:web/member:backup.client"
        ];
    };
}
