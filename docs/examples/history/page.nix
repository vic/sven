{
  title = "Impact, without, and time";
  description = "What a scope's elements reach, the fleet without the files of one declaration, and instances valid at a date.";
  section = "agents";
  order = 6;

  body =
    {
      docs,
      r,
      engine,
      module,
      dir,
      ...
    }:
    let
      files = [
        (dir + "/modules/fleet.nix")
        (dir + "/modules/features/backend.nix")
      ];
      w = engine.without {
        inherit files;
        path = [
          "aspects"
          "backend"
        ];
        args = module._module.args;
      };
    in
    [
      ''
        Three questions an agent asks before a change: what else does this touch, what if this were gone, and what
        holds on a given day.
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/features/backend.nix")
      ''
        ## What does this scope reach?

        `r.impact id { hops; sinks; max; }` follows routed elements from a scope, by depth. `web` gives a backend
        to its environment, and the environment gives DNS to the fleet:
      ''
      (docs.value (r.impact "fleet:main/environment:prod/host:web" { }))
      ''
        ## What if it were gone?

        `yen.lib.without { files; path; args; }` evaluates the fleet without the files that declare `path`.
        A whole file goes: there is no hook to remove part of one.
      ''
      (docs.value {
        dropped = map baseNameOf w.dropped;
        dns = w.r.flake.dns or null;
        errors = w.r.errors;
      })
      ''
        ## Valid time

        Pure evaluation has no clock, so the date is data. An instance with `validFrom` and `validTo` holds at the date
        the caller passes: `yen.lib.validAt date scope`. Here the environment spawns only the hosts valid today,
        so `web-old` and `web-next` have no scope:
      ''
      (docs.value (map (s: s.id) r.scopes))
      ''
        ## Transaction time

        `yen.lib.asOf { url; rev; module; }` evaluates the fleet at a git revision. `yen.lib.history { url; revs; module; }`
        lists each revision with the field changes from the one before (`diffData` over `r.data`). The engine's own tests
        run both on this repository: see [tests/default.nix](https://github.com/vic/yen/blob/main/tests/default.nix).
      ''
    ];

  checks =
    {
      r,
      engine,
      module,
      dir,
      ...
    }:
    let
      w = engine.without {
        files = [
          (dir + "/modules/fleet.nix")
          (dir + "/modules/features/backend.nix")
        ];
        path = [
          "aspects"
          "backend"
        ];
        args = module._module.args;
      };
    in
    {
      impact =
        map (x: x.scope) (r.impact "fleet:main/environment:prod/host:web" { }).reached == [
          "fleet:main/environment:prod"
          "fleet:main"
        ];
      valid =
        builtins.filter (s: s.kind == "host") r.scopes != [ ]
        && map (s: s.name) (builtins.filter (s: s.kind == "host") r.scopes) == [ "web" ];
      without = map baseNameOf w.dropped == [ "backend.nix" ];
    };
}
