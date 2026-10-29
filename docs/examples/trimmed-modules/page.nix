{
  title = "Trimmed module lists";
  description = "Evaluate only the NixOS base modules a host needs, with a drvPath oracle that proves the system is the same.";
  section = "perf";
  order = 2;
  badge = "advanced";

  body =
    { docs, ... }:
    [
      ''
        NixOS evaluates about 1,900 base modules for every host, used or not. A host with `trimmedModules = true` in the
        reference fleet evaluates only the ones it needs: about 400.

        The list is the closure of a learned core and the options the host defines. It filters `module-list.nix` itself,
        so the order and the inline entries stay. The host passes it to `nixosSystem` as `baseModules`.
      ''
      (docs.table
        [ "Reference fleet: web-1, app-2 toplevel" "CPU" "Thunks" "GC total" ]
        [
          [
            "full list"
            "11.4 s"
            "14.57 M"
            "1.03 GB"
          ]
          [
            "trimmed list"
            "10.5 s"
            "13.21 M"
            "0.94 GB"
          ]
        ]
      )
      ''
        ## Three oracles

        - `modlist-same-drv`: each trimmed toplevel has the same `drvPath` as the full build.
        - `modlist-negative`: the list without nginx fails for a host that runs nginx, and the same list with nginx builds.
        - `cost.sh`: the trimmed eval uses at most 95% of the thunks.
      ''
      (docs.caution "One nixpkgs revision" ''
        A list belongs to one nixpkgs revision. After an update, `modlist-same-drv` fails until you compute the lists again.
        Use this only with the oracle in CI.
      '')
      (docs.links [
        {
          title = "platforms/nixos.nix";
          href = "https://github.com/vic/yen/blob/main/templates/fleet/modules/platforms/nixos.nix";
          description = "The host sink: trimmed, full and own-pkgs builds.";
        }
        {
          title = "modlist research";
          href = "https://github.com/vic/yen/blob/main/vic/modlist-research.md";
          description = "How the lists are computed.";
        }
      ])
    ];
}
