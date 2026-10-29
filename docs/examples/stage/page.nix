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
            sven = inputs.sven.outPath;
            inherit (inputs) nixpkgs import-tree;
          }
          // args
        );
      desktop = S { change = "changes/desktop-on-web.json"; };
      grant = engine.grant { scopes = [ "fleet:main/host:db" ]; };
    in
    [
      ''
        Before you apply a change, stage it. `sven.lib.stage { base; change; rejected; grant; }` evaluates the fleet
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

        `sven.lib.grant { scopes = [ id prefixes ]; sinks ? null; }` says where a change may give elements.
        `narrow g h` keeps what both allow. No function makes a grant wider. An element outside the grant is refused,
        with `class = "authority"`: no edit by this author can fix it.
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
      ...
    }:
    let
      S =
        args:
        import (dir + "/stage.nix") (
          {
            sven = inputs.sven.outPath;
            inherit (inputs) nixpkgs import-tree;
          }
          // args
        );
      d = S { change = "changes/desktop-on-web.json"; };
    in
    {
      violation = !d.ok && d.violations == [ "bad:desktop-on-server:web" ];
      clean = (S { change = "changes/postgres-on-thinkpad.json"; }).ok;
      grant =
        map (e: e.code)
          (S {
            change = "changes/postgres-on-thinkpad.json";
            grant = engine.grant { scopes = [ "fleet:main/host:db" ]; };
          }).refused == [ "outside-grant" ];
      rejected =
        map (e: e.code)
          (S {
            change = "changes/desktop-on-web.json";
            rejected = [ d.sha ];
          }).refused == [ "rejected" ];
    };
}
