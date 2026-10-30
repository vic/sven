# cachix: a cache is data; the host trusts it, the flake asks to trust it, CI pushes to it.
{ yen, ... }:
let
  inherit (yen.lib.batteries) cachix github files;
in
{
  yen.kinds.host.sinks.caches.nixos = cachix.caches { from = yen.kinds.host.sinks.caches; };
  yen.kinds.repo.sinks.caches.out = cachix.flake-config { from = yen.kinds.repo.sinks.caches; };
  yen.aspects.caches = {
    at = [
      yen.kinds.host
      yen.kinds.repo
    ];
    caches = {
      name = "nix-community";
      publicKey = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    };
  };
  # the CI job that pushes to the cache
  yen.kinds.repo.sinks.jobs = {
    reduce = yen.lib.reduce.merge;
    files = github.workflow {
      from = yen.kinds.repo.sinks.jobs;
      path = ".github/workflows/build.yml";
      doc = {
        name = "build";
        on.push = { };
      };
      header = _: files.comment "build.yml" "Generated.";
    };
  };
  yen.aspects.build-job = {
    at = yen.kinds.repo;
    jobs.build = {
      runs-on = "ubuntu-latest";
      steps = [
        (cachix.action { name = "my-cache"; })
        { run = "nix build .#nixosConfigurations.build.config.system.build.toplevel"; }
      ];
    };
  };
}
