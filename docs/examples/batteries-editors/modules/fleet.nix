# Standalone homes. Language aspects add editor extensions and settings; AI tools add agent extensions.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  b = yen.lib.batteries;
in
{
  yen.kinds.fleet = {
    spawns.home = _: yen.home;
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.home = {
    sinks = {
      homeManager.out = b.home-manager.system {
        from = yen.kinds.home.sinks.homeManager;
        homeManagerConfiguration = _: inputs.home-manager.lib.homeManagerConfiguration;
        pkgs = _: inputs.nixpkgs.legacyPackages.x86_64-linux;
      };
      vscode.homeManager = b.editors.vscode { from = yen.kinds.home.sinks.vscode; };
      zed.homeManager = b.editors.zed { from = yen.kinds.home.sinks.zed; };
      # one pool of agent extensions; each agent picks the types it reads
      agent-ext.homeManager = b.ai.extensions {
        from = yen.kinds.home.sinks.agent-ext;
        types = [ "skill" ];
        build = skills: {
          home.file = lib.listToAttrs (
            map (s: lib.nameValuePair ".claude/skills/${s.name}" { source = s.path; }) skills
          );
        };
      };
    };
  };
  yen.fleet.main = { };
  yen.home.ana = { };
  yen.flake = { out, ... }: out;
  yen.aspects.home = {
    at = yen.kinds.home;
    homeManager =
      { scope, ... }:
      {
        home.username = scope.name;
        home.homeDirectory = "/home/${scope.name}";
        home.stateVersion = "25.05";
        nixpkgs.config.allowUnfree = true; # vscode
      };
  };
}
