# A role is an aspect whose `at` is a fact test. Roles build on roles.
{ yen, lib, ... }:
let
  inherit (yen.lib) all not;
in
{
  yen.aspects = {
    server.at = s: (s.form or null) == "server";
    workstation.at =
      s:
      lib.elem (s.form or null) [
        "laptop"
        "desktop"
      ];
    laptop.at = s: (s.form or null) == "laptop";
    nvidia.at = s: (s.gpu or null) == "nvidia";
    ci-runner.at = s: lib.elem "ci-runner" (s.labels or [ ]);
    gaming.at = all [
      yen.aspects.workstation
      yen.aspects.nvidia
      (not yen.aspects.laptop)
    ];
    backups.at = [
      yen.aspects.server
      yen.aspects.workstation
    ];
  };
}
