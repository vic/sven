{
  title = "nix-darwin machines";
  description = "NixOS hosts and macs in one fleet. Aspects write `os` once; each platform forwards it.";
  section = "recipes";
  order = 3;

  body =
    { docs, result, ... }:
    [
      ''
        Many options mean the same on NixOS and nix-darwin: `networking.hostName`, `environment.systemPackages`,
        `nix.settings`. Write them once. A `host` forwards its `os` sink to `nixos`, and a `mac` forwards it to `darwin`.
      ''
      (docs.fileWith "{12-13,24-25}" "modules/platforms.nix")
      (docs.file "modules/shared.nix")
      (docs.file "modules/machines.nix")
      ''
        The routes: `shared` gives `os` at each machine, and each `os` sink feeds its platform's sink:
      ''
      (docs.routes result)
      (docs.sh ''
        sudo nixos-rebuild switch --flake .#server
        sudo darwin-rebuild switch --flake .#studio
      '')
      (docs.note "Platform-only content" ''
        Keep platform-only options under their own key: `nixos` for NixOS, `darwin` for nix-darwin. An aspect active at both
        kinds can give `os`, `nixos` and `darwin` at the same time; each element goes where its sink is.
      '')
    ];

  checks =
    { result, ... }:
    {
      forwards =
        builtins.any (e: e.sink == "darwin" && e.origin == "sink os") result.graph.edges
        && builtins.any (e: e.sink == "nixos" && e.origin == "sink os") result.graph.edges;
    };
  e2e =
    { flake, ... }:
    {
      mac = flake.darwinConfigurations.studio.config.networking.hostName == "studio";
      mac-git = builtins.any (
        p: (p.pname or "") == "git"
      ) flake.darwinConfigurations.studio.config.environment.systemPackages;
      host = flake.nixosConfigurations.server.config.networking.hostName == "server";
    };
}
