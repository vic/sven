{
  title = "osConfig in home-manager";
  description = "A home-manager module reads its host's NixOS config, nested in NixOS or as a standalone home.";
  section = "recipes";
  order = 8;

  body =
    { docs, ... }:
    [
      ''
        A home-manager module often needs its host's NixOS config: `{ osConfig, pkgs, ... }:`.
        In yen, `osConfig` is a sink. Each host gives its realized config to it, and a module names it like any sink arg.
        `pkgs` stays open, so home-manager fills its own `pkgs`.
      ''
      (docs.fileWith "{16-28,58-61}" "modules/fleet.nix")
      ''
        - The `os-config` aspect gives `out.nixosConfigurations.<host>.config`. It is lazy: Nix reads it only when a module asks.
        - A home has `on`, so it lives under that host. It reads the host's sinks like any child, and still builds `homeConfigurations`.
      ''
      (docs.fileWith "{22-33}" "modules/alice.nix")
      ''
        `editors` lands in two places: in the server's NixOS (`home-manager.users.alice`) and in `homeConfigurations."alice@server"`.
        Both read the same `osConfig`.
      ''
      (docs.sh ''
        sudo nixos-rebuild switch --flake .#server
        home-manager switch --flake '.#alice@server'
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
      both = {
        t1 = yes (result.active.editors."fleet:main/host:server/home:alice@server");
        t2 = yes (result.active.editors."fleet:main/host:server/user:alice");
      };
    };
  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    let
      nano = c: builtins.any (p: (p.pname or "") == "nano") c.home.packages;
      nested = flake.nixosConfigurations.server.config.home-manager.users.alice;
      standalone = flake.homeConfigurations."alice@server".config;
    in
    {
      nested = {
        t1 = eq (nested.home.sessionVariables.EDITOR_HOST) ("server");
        t2 = yes (nano nested);
      };
      standalone = {
        t1 = eq (standalone.home.sessionVariables.EDITOR_HOST) ("server");
        t2 = yes (nano standalone);
      };
      standalone-builds = yes (flake.homeConfigurations."alice@server".activationPackage ? drvPath);
    };
}
