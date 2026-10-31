let
  # the host `web`, as a caller outside the fleet names it: its identity
  web = {
    kind = "host";
    name = "web";
  };
in
{
  title = "Impact, without, and time";
  description = "What a scope's elements reach, the fleet without the files of one declaration, and instances valid at a date.";
  section = "agents";
  order = 6;

  body =
    {
      docs,
      result,
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
        args = { inherit (module) inputs lib yen; };
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

        `result.impact scope { hops; sinks; max; }` follows routed elements from a scope, by depth. The scope is a ref (`{ kind; name; }`
        from outside the fleet), each sink a ref or `{ sink; }`, and each scope it reaches is a path of refs. `web` gives a backend
        to its environment, and the environment gives DNS to the fleet:
      ''
      (docs.value (result.impact web { }))
      ''
        ## What if it were gone?

        `yen.lib.without { files; path; args; }` evaluates the fleet without the files that declare `path`.
        A whole file goes: there is no hook to remove part of one.
      ''
      (docs.value {
        dropped = map baseNameOf w.dropped;
        dns = w.result.flake.dns or null;
        errors = w.result.errors;
      })
      ''
        ## Valid time

        Pure evaluation has no clock, so the date is data. An instance with `validFrom` and `validTo` holds at the date
        the caller passes: `yen.lib.validAt date scope`. Here the environment spawns only the hosts valid today,
        so `web-old` and `web-next` have no scope:
      ''
      (docs.value (map (s: s.id) result.scopes))
      ''
        ## Transaction time

        `yen.lib.asOf { url; rev; module; }` evaluates the fleet at a git revision. `yen.lib.history { url; revs; module; }`
        lists each revision with the field changes from the one before (`diffData` over `result.data`). The engine's own tests
        run both on this repository: see [tests/default.nix](https://github.com/vic/yen/blob/main/tests/default.nix).
      ''
    ];

  checks =
    {
      result,
      engine,
      module,
      dir,
      eq,
      yes,
      no,
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
        args = { inherit (module) inputs lib yen; };
      };
    in
    {
      impact = eq (map (x: x.scope) (result.impact web { }).reached) ([
        [
          {
            kind = "fleet";
            name = "main";
          }
          {
            kind = "environment";
            name = "prod";
          }
        ]
        [
          {
            kind = "fleet";
            name = "main";
          }
        ]
      ]);
      valid = {
        t1 = yes (builtins.filter (s: s.kind == "host") result.scopes != [ ]);
        t2 = eq (map (s: s.name) (builtins.filter (s: s.kind == "host") result.scopes)) ([ "web" ]);
      };
      without = eq (map baseNameOf w.dropped) ([ "backend.nix" ]);
    };
}
