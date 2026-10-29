# One system scope per platform: per-system flake outputs.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.lib.reduce) merge;
  pkgs = s: inputs.nixpkgs.legacyPackages.${s.name};
in
{
  yen.kinds.system.sinks = {
    packages = {
      reduce = merge;
      out =
        { system, packages, ... }:
        {
          packages.${system.name} = packages;
        };
    };
    checks = {
      reduce = merge;
      out =
        { system, checks, ... }:
        {
          vmTests.${system.name} =
            lib.mapAttrs
              # VM tests need KVM: not flake checks. Run: nix build .#vmTests.x86_64-linux.web
              (
                name: m:
                (pkgs system).testers.runNixOSTest {
                  imports = [ m ];
                  inherit name;
                }
              )
              checks;
        };
    };
    no-gui = {
      # reads the realized lb from `out`, writes `out.checks`: laziness, not strata
      of = lib.types.attrsOf (lib.types.listOf lib.types.str);
      reduce = merge;
      out =
        {
          system,
          out,
          no-gui,
          ...
        }:
        {
          checks.${system.name} = lib.mapAttrs' (
            h: bad:
            lib.nameValuePair "${h}-no-gui" (yen.helpers.noGui system h out.nixosConfigurations.${h} bad)
          ) no-gui;
        };
    };
  };
  yen.system = lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (_: { });
}
