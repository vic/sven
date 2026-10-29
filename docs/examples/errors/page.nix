{
  title = "Errors as data";
  description = "yen never throws. Errors are records you query; your own checks add to them.";
  section = "concepts";
  order = 13;

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
        This fleet has two hosts with one address:
      ''
      (docs.file "modules/fleet.nix")
      (docs.fileWith "{9-15}" "modules/checks.nix")
      (docs.value result.errors)
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

  errors = true; # this example shows a duplicate address on purpose

  checks =
    { result, variant, ... }:
    {
      duplicate =
        map (e: {
          inherit (e)
            code
            error
            from
            class
            ;
        }) result.errors == [
          {
            code = "duplicate-addr";
            error = "10.0.0.1 is the address of db and web";
            from = "fleet:main";
            class = "fixable";
          }
        ];
      warnings = result.flake.warnings == [ "scratch has no backup" ];
      typo = builtins.any (
        e: e.code == "unknown-field" && e.near == [ "backup" ]
      ) (variant "variants/typo.nix").errors;
    };
}
