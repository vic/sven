# A repo: one root scope that writes repo files, and one scope per system for its dev shell.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib.batteries) files devshell;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in
{
  yen.kinds.repo = {
    spawns.system = _: yen.system;
    sinks = {
      out.reduce = yen.lib.reduce.merge;
      # every key below that gives to `files` becomes a repo file, written by `nix run .#write-files`
      files.out = files.writer {
        from = yen.kinds.repo.sinks.files;
        inherit (inputs) files;
        inherit lib pkgs;
        root = inputs.self;
      };
    };
  };
  yen.kinds.system.sinks.shell.out = devshell.mkshell {
    from = yen.kinds.system.sinks.shell;
    pkgsOf = s: inputs.nixpkgs.legacyPackages.${s.name};
  };
  yen.repo.main = { };
  yen.system.x86_64-linux = { };
  yen.flake = { out, ... }: out;

  yen.aspects.shell-tools = {
    at = yen.kinds.system;
    shell.packages = [ ];
    shell.shellHook = "echo hello\n";
  };
}
