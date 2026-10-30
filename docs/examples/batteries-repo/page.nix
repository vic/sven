{
  title = "Repo batteries";
  description = "files, github, devshell, flake-file: README, CI workflow, ci.json, dev shell and flake.nix, written from fleet data.";
  section = "batteries";
  route = "batteries/repo";
  order = 3;

  body =
    { docs, result, ... }:
    [
      ''
        A repo has files that should follow the code: the README, the CI workflow, a matrix of CI targets, the dev shell,
        `flake.nix`. These batteries write them from sinks, so any aspect can add a section, a job, a target or an input.
        [github:sini/files](https://github.com/sini/files) writes them (`nix run .#write-files`) and gives a check per
        file: CI fails when a committed file is stale.

        | Battery | Value of | Writes |
        |---|---|---|
        | `files.writer { from; files; lib; pkgs; root; relativeRoot; }` | `out` of the files sink | `packages.<system>.write-files` and a check per file |
        | `files.document { from; path; separator; }` | a key that gives to the files sink | one file from the texts of a sink (with `ordered`: sections in order) |
        | `files.json { from; path; value; }` | the same | the JSON of a sink |
        | `files.toml { inline; }` | a function | TOML text from a Nix value |
        | `files.comment path text` | a function | a notice in the comment syntax of the file's format |
        | `github.workflow { from; path; doc; header; }` | a key that gives to the files sink | a workflow from a sink of jobs |
        | `github.yaml` | a function | YAML text from a Nix value |
        | `devshell.mkshell { from; pkgsOf; }` | `out` of a sink of `{ packages; shellHook; }` | `devShells.<scope name>.default` |
        | `devshell.numtide { from; devshell; systems; pkgsOf; name; packages; }` | `out` of a sink of command lists | a numtide/devshell per system |
        | `flake-file.write { from; lib; inputs; pkgs; modules; }` | `out` of a merge sink | `packages.<system>.write-flake` and its check |
      ''
      (docs.file "modules/repo.nix")
      (docs.file "modules/readme.nix")
      (docs.file "modules/ci.nix")
      (docs.file "modules/flake-file.nix")
      (docs.file "modules/more.nix")
      ''
        The files the aspects give, as the files sink holds them:
      ''
      (docs.value (
        map (m: builtins.mapAttrs (_: f: f.text) m.files.file) result.reduced.files."repo:main"
      ))
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    let
      texts = builtins.foldl' (
        a: m: a // builtins.mapAttrs (_: f: f.text) m.files.file
      ) { } result.reduced.files."repo:main";
    in
    {
      readme = eq (texts."README.md") (
        "# my repo\n<!-- Generated. Run nix run .#write-files. -->\n\n## Usage"
      );
      workflow = eq (texts.".github/workflows/ci.yml") (
        "# Generated. Jobs: check\n\"jobs\":\n  \"check\":\n    \"runs-on\": \"ubuntu-latest\"\n    \"steps\":\n      -\n        \"uses\": \"actions/checkout@v4\"\n      -\n        \"run\": \"nix flake check\"\n\"name\": \"ci\"\n\"on\":\n  \"push\": {}\n"
      );
      json = eq (texts."ci.json") ("[\"devShells.x86_64-linux.default\"]\n");
      toml = eq (texts."taplo.toml") ("[formatting]\nalign_entries = true\n");
      yaml = eq (builtins.substring 0 14 texts.".github/dependabot.yml") ("\"updates\":\n  -");
      outputs = eq (builtins.attrNames result.flake.packages.x86_64-linux) ([
        "write-files"
        "write-flake"
      ]);
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    {
      write-files = yes (builtins.isString flake.packages.x86_64-linux.write-files.drvPath);
      write-flake = yes (builtins.isString flake.packages.x86_64-linux.write-flake.drvPath);
      file-checks = eq (builtins.length (builtins.attrNames flake.checks.x86_64-linux)) (6);
      numtide = yes (builtins.isString flake.devShells.x86_64-linux.repo.drvPath);
      shell = yes (builtins.isString flake.devShells.x86_64-linux.default.drvPath);
    };
}
