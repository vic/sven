# Checks derived from the infra: aspects state facts from fleet data; `checks.x86_64-linux.infra-<host>` compares each fact with the realized NixOS config.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  # a fact: { path; eq; } or { path; has; via ? id; }. `via` maps each realized list item first (impermanence makes { directory; … })
  holdsIn =
    cfg: f:
    let
      got = lib.attrByPath f.path null cfg;
    in
    if f ? has then lib.isList got && lib.elem f.has (map (f.via or (x: x)) got) else got == f.eq;
  check =
    h: cfg: facts:
    let
      bad = lib.filter (f: !holdsIn cfg f) facts;
    in
    pkgs.runCommand "infra-${h}" { } (
      if bad == [ ] then
        "touch $out"
      else
        "echo ${lib.escapeShellArg "infra ${h}: ${lib.concatMapStringsSep "; " (f: lib.concatStringsSep "." f.path) bad}"}; exit 1"
    );
in
{
  yen.kinds.fleet.sinks.infra = {
    reduce = yen.lib.reduce.merge;
    out =
      { infra, out, ... }:
      {
        checks.x86_64-linux = lib.mapAttrs' (
          h: facts:
          lib.nameValuePair "infra-${h}" (check h out.nixosConfigurations.${h}.config (lib.attrValues facts))
        ) infra;
      };
  };
  yen.aspects.infra-base = {
    at = yen.lib.all [
      yen.kinds.host
      (s: !s.minimal)
    ];
    infra =
      { host, persist, ... }:
      {
        ${host.name} = {
          hostname = {
            path = [
              "networking"
              "hostName"
            ];
            eq = host.name;
          };
        }
        // lib.listToAttrs (
          map (
            d:
            lib.nameValuePair "persist ${d}" {
              path = [
                "environment"
                "persistence"
                "/persist"
                "directories"
              ];
              has = d;
              via = x: x.directory or x;
            }
          ) (lib.subtractLists host.unpersist persist)
        );
      };
  };
  yen.aspects.infra-web = {
    at = yen.lib.all [
      yen.aspects.nginx
      (s: !s.minimal)
    ];
    infra =
      { host, ... }:
      {
        ${host.name} = {
          nginx = {
            path = [
              "services"
              "nginx"
              "enable"
            ];
            eq = true;
          };
          port80 = {
            path = [
              "networking"
              "firewall"
              "allowedTCPPorts"
            ];
            has = 80;
          };
        };
      };
  };
}
