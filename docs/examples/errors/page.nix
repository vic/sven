{
  title = "Errors as data";
  description = "yen never throws. Errors are records you query; your own checks add to them.";
  section = "principles";
  order = 2;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        yen never calls `throw`. When something is wrong, the read gives `null`, evaluation continues,
        and the `errors` query lists a record. An empty list means the fleet is valid.

        ## Error records

        Each record has `error` and `from` for people, and `code`, `path`, `got`, `want`, `fix`, `class` and `near`
        for tools and agents. `class` is `fixable` when an edit to the data fixes it, and `authority` when no edit
        by this author can.
      ''
      (docs.file "variants/typo.nix")
      (docs.value (variant "variants/typo.nix").errors)
      ''
        ## Your own checks

        An aspect key `errors` gives records, or plain messages. yen sets `from` to the scope that gave it: an aspect cannot
        report for another scope. A record without `class` is `fixable`.
        Here `unique-addr` checks that no two hosts share an address:
      ''
      (docs.file "modules/fleet.nix")
      (docs.fileWith "{9-15}" "modules/checks.nix")
      ''
        A new host with the address of `web` gives an error record:
      ''
      (docs.file "variants/duplicate.nix")
      (docs.value (variant "variants/duplicate.nix").errors)
      ''
        A fleet with an error gives no outputs. Its `flake` is `{ invalid-flake-errors = { errors; violations; incomplete; }; }`
        until `errors` is `[ ]` and every invariant holds: a build finds no output, and `nix eval .#invalid-flake-errors`
        tells you, or an agent, why:
      ''
      (docs.value (variant "variants/duplicate.nix").flake)
      ''
        ## Warnings

        A warning is a message that does not fail the fleet. It is a plain sink with `list` reduce, here given
        to the flake as `warnings`:
      ''
      (docs.value result.flake.warnings)
      (docs.tip "Gate CI on it" ''
        In CI, fail when `errors` is not `[ ]`, before any build. A `query.nix` gives every query on the command line:
        see [Project layout](/start/project-layout/).
      '')
    ];

  checks =
    {
      result,
      variant,
      eq,
      yes,
      no,
      ...
    }:
    {
      duplicate =
        eq
          (map (e: {
            inherit (e)
              code
              error
              from
              class
              ;
          }) (variant "variants/duplicate.nix").errors)
          ([
            {
              code = "duplicate-addr";
              error = "10.0.0.1 is the address of cache and web";
              from = "fleet:main";
              class = "fixable";
            }
          ]);
      no-outputs = eq (builtins.attrNames (variant "variants/duplicate.nix").flake) ([
        "invalid-flake-errors"
      ]);
      warnings = eq (result.flake.warnings) ([ "scratch has no backup" ]);
      typo = yes (
        builtins.any (e: e.code == "unknown-field" && e.near == [ "backup" ])
          (variant "variants/typo.nix").errors
      );
    };
}
