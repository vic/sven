{
  title = "Assemblies and roles";
  description = "Assemblies as data: each machine gets one member scope per role, and members exchange data.";
  section = "recipes";
  order = 9;
  badge = "advanced";

  body =
    { docs, result, ... }:
    [
      ''
        A backup has roles: one server, many clients. An assembly says which machine takes which role, with refs.
      ''
      (docs.file "modules/inventory.nix")
      ''
        Each machine spawns one `member` scope per (assembly, role) it takes part in. The member holds a ref to its
        assembly. An aspect at a member scope runs once per assembly and role. An aspect at a machine that `has` a
        member runs once per machine.
      ''
      (docs.fileWith "{12-15,33}" "modules/kinds.nix")
      (docs.scopes result)
      ''
        ## Members exchange data

        Clients publish their address to a fleet sink with `entries`. The engine sets `from`, so a member can only publish
        as itself. The server reads the entries and builds its allow list:
      ''
      (docs.fileWith "{9,15}" "modules/backup.nix")
      (docs.value result.flake.config)
      (docs.tip "The full model" ''
        [Kits batteries](/batteries/kits/) add kits as data with typed role settings and errors, `at` predicates as
        role members, exports with owner overrides, and vars generators. The
        [reference fleet](https://github.com/vic/yen/blob/main/templates/fleet/modules/kits/assemblies.nix) uses them.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      allow = eq (result.flake.config.nas.backup.allow) ([
        "10.0.0.1"
        "10.0.0.2"
      ]);
      members = eq (map (s: s.id) (builtins.filter (s: s.kind == "member") result.scopes)) ([
        "fleet:main/host:db/member:backup.client"
        "fleet:main/host:nas/member:backup.server"
        "fleet:main/host:web/member:backup.client"
      ]);
    };
}
