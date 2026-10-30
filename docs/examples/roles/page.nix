{
  title = "Roles from data";
  description = "A role is an aspect whose `at` tests a fact. No host file lists its roles.";
  section = "recipes";
  order = 2;

  body =
    { docs, result, ... }:
    [
      ''
        Host files that list roles drift: someone adds a GPU and forgets the line. Put the facts on the host instead,
        and let each role test them.
      ''
      (docs.fileWith "{12-14}" "modules/kinds.nix")
      (docs.file "modules/roles.nix")
      ''
        Roles combine like any predicate: `gaming` is a workstation with an nvidia GPU that is not a laptop.
        A role gives content with the usual keys (`nixos`, `homeManager`, …), and other aspects can use it in `at`.

        ## Tags for deploy tools

        `yen.lib.holds` asks a predicate at a scope. One aspect turns the active roles into tags:
      ''
      (docs.file "modules/tags.nix")
      (docs.value result.flake.tags)
      (docs.tip "Change a fact, not a list" ''
        Give `rack-2` the label `ci-runner`, and it gets the role, its content and its tag. Nothing else changes.
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
      tags = eq (result.flake.tags) ({
        rack-1 = [
          "server"
          "ci-runner"
          "backups"
        ];
        rack-2 = [
          "server"
          "backups"
        ];
        thinkpad = [
          "workstation"
          "laptop"
          "backups"
        ];
        tower = [
          "workstation"
          "nvidia"
          "gaming"
          "backups"
        ];
      });
    };
}
