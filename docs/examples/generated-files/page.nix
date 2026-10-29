{
  title = "Generated files";
  description = "flake.nix by flake-file, README.md and the CI workflow by sini/files: written from fleet data, and checked in CI.";
  section = "recipes";
  order = 7;

  body =
    { docs, r, ... }:
    [
      ''
        Some repo files are views of your fleet: the flake's inputs, a README with the host diagram, a CI workflow.
        Write them from the data, and a check fails when a committed file is stale.
        [denful/flake-file](https://github.com/denful/flake-file) writes `flake.nix`.
        [sini/files](https://github.com/sini/files) writes `README.md` and the CI workflow. sven gives both the content.

        These docs are made this way: every page you read is a file that the docs fleet writes. So is sven's CI workflow:
        each stage is an aspect, and one job per system comes from the reference fleet's `ci.json`
        ([docs/modules/ci.nix](https://github.com/vic/sven/blob/main/docs/modules/ci.nix)).
      ''
      (docs.fileWith "{17-36}" "modules/fleet.nix")
      ''
        ## Inputs live with their users

        Each aspect declares the flake inputs it uses on the `flake-file` sink. The host's input goes up to the fleet:
      ''
      (docs.fileWith "{29}" "modules/inputs.nix")
      ''
        ## README and CI workflow

        The `files` sink collects `sini/files` modules. One aspect writes the README, with a single mermaid diagram of the fleet's hosts, and the CI workflow:
      ''
      (docs.file "modules/write.nix")
      ''
        The template's own `flake.nix` is the `flake-file` output. Remove the `web` aspect, and `nixpkgs` leaves the flake.
      ''
      (docs.file "flake.nix")
      (docs.file "README.md")
      (docs.file ".github/workflows/ci.yml")
      (docs.sh ''
        nix run .#write-flake   # write flake.nix
        nix run .#write-files   # write README.md and the CI workflow
        nix flake check         # fails when a committed file is stale
      '')
    ];

  checks =
    { r, dir, ... }:
    let
      gen = (builtins.head r.reduced.files."fleet:main").files.file;
    in
    {
      readme = gen."README.md".text == builtins.readFile (dir + "/README.md");
      readme-mermaid = builtins.match ".*```mermaid\n.*" gen."README.md".text != null;
      ci = gen.".github/workflows/ci.yml".text == builtins.readFile (dir + "/.github/workflows/ci.yml");
      inputs =
        builtins.attrNames r.reduced.flake-file."fleet:main".inputs == [
          "files"
          "flake-file"
          "import-tree"
          "nixpkgs"
          "nixpkgs-unstable"
          "sven"
        ];
    };
}
