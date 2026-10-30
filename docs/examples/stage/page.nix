{
  title = "Stage a change";
  description = "Evaluate the fleet without and with a change. New errors, new violations, a diff, and refusals with their reason.";
  section = "agents";
  order = 2;

  body =
    {
      docs,
      inputs,
      dir,
      engine,
      ...
    }:
    let
      S =
        args:
        import (dir + "/stage.nix") (
          {
            yen = inputs.yen.outPath;
            inherit (inputs) nixpkgs import-tree;
          }
          // args
        );
      desktop = S { change = "changes/desktop-on-web.json"; };
      grant = engine.grant { scopes = [ "fleet:main/host:db" ]; };
    in
    [
      ''
        Before you apply a change, stage it. `yen.lib.stage { base; change; rejected; grant; }` evaluates the fleet
        without and with the change. Nothing is applied. `ok` is true only when nothing new is wrong.

        The fleet is the one from [Invariants](/query/invariants/). A change is plain data, so an agent can write it as JSON:
      ''
      (docs.file "changes/desktop-on-web.json")
      (docs.file "stage.nix")
      (docs.sh "nix eval --impure --json --file stage.nix --argstr change changes/desktop-on-web.json")
      (docs.value desktop)
      ''
        The change makes `desktop` active at the server `web`, and breaks an invariant. The answer has the violation,
        the diff (scopes, routed elements, active aspects) and the change's `sha`.

        ## Grants only narrow

        `yen.lib.grant { scopes = [ id prefixes ]; sinks ? null; }` says where a change may reach. A prefix covers a scope
        and the scopes under it, by path segment. `narrow g h` keeps what both allow. No function makes a grant wider.

        Every yen module can read the whole fleet through `yen`, so a change that declares anything can reach every scope
        and every sink. yen refuses each scope the grant does not cover, with `class = "authority"`: no edit by this
        author can fix it. This is coarse, and it is sound: a value that one scope reads from another never escapes the grant.
      ''
      (docs.file "changes/postgres-on-thinkpad.json")
      (docs.value
        (S {
          change = "changes/postgres-on-thinkpad.json";
          inherit grant;
        }).refused
      )
      ''
        ## Rejected before

        Pass the `sha` of changes refused before in `rejected`. The same change is refused again, whoever sends it:
      ''
      (docs.value
        (S {
          change = "changes/desktop-on-web.json";
          rejected = [ desktop.sha ];
        }).refused
      )
      ''
        ## A change from Nix

        `yen.lib.change.set path value` writes the same data from Nix: one declaration path gets one value.
        This gives the change in `desktop-on-web.json`:
      ''
      (docs.nix ''
        yen.lib.change.set [ "aspects" "desktop" "at" ] [ { kind = "host"; name = "web"; } ]
      '')
      (docs.tip "Safe places for an aspect" ''
        A stored query can stage an aspect on each machine and return where it is safe, and why the others are refused.
        See `safeHostsFor` in the reference fleet's ${
          docs.fleet "modules/agent/synthesis.nix" null "agent/synthesis.nix"
        }.
      '')
    ];

  checks =
    {
      inputs,
      dir,
      engine,
      eq,
      yes,
      no,
      ...
    }:
    let
      S =
        args:
        import (dir + "/stage.nix") (
          {
            yen = inputs.yen.outPath;
            inherit (inputs) nixpkgs import-tree;
          }
          // args
        );
      d = S { change = "changes/desktop-on-web.json"; };
    in
    {
      violation = {
        t1 = no (d.ok);
        t2 = eq (d.violations) ([
          [
            "bad"
            "no-desktop-on-servers"
            "fleet:main/host:web"
          ]
        ]);
      };
      clean = yes ((S { change = "changes/postgres-on-thinkpad.json"; }).ok);
      grant =
        let
          r =
            (S {
              change = "changes/postgres-on-thinkpad.json";
              grant = engine.grant { scopes = [ "fleet:main/host:db" ]; };
            }).refused;
        in
        {
          t1 = yes (builtins.all (e: e.code == "outside-grant") r);
          t2 = yes (builtins.elem "fleet:main/host:thinkpad" (map (e: e.got) r));
          t3 = no ((builtins.elem "fleet:main/host:db" (map (e: e.got) r)));
        };
      rejected = eq (map (e: e.code)
        (S {
          change = "changes/desktop-on-web.json";
          rejected = [ d.sha ];
        }).refused
      ) ([ "rejected" ]);
      change-set = eq (engine.change.set
        [ "aspects" "desktop" "at" ]
        [
          {
            kind = "host";
            name = "web";
          }
        ]
      ) (builtins.fromJSON (builtins.readFile (dir + "/changes/desktop-on-web.json")));
    };
}
