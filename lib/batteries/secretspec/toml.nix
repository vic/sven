# secretspec.toml (github:cachix/secretspec) from sink `from`: each element declares one secret,
# `{ name; profile ? "default"; description ? ; required ? ; default ? ; providers ? ; … }`. The value of a key that
# gives to the files sink. Give the sink `reduce = yen.lib.batteries.claim { key = s: "${s.profile or "default"}/${s.name}"; }`
# so one secret declared twice is an error; a list reduce works too.
#   files = secretspec.toml { from = yen.kinds.repo.sinks.secrets; project.name = "app"; };
{
  from,
  project,
  path ? "secretspec.toml",
  defaults ? { },
  providers ? { },
  profiles ? { },
}:
{ sinks, ... }:
let
  b = builtins;
  toml = import ../files/toml.nix { };
  raw = sinks.${from.__sink};
  secrets = if b.isAttrs raw then b.attrValues raw else raw;
  profileOf = s: s.profile or "default";
  declared = b.mapAttrs (
    _: ss:
    b.listToAttrs (
      map (s: {
        inherit (s) name;
        value = b.removeAttrs s [
          "name"
          "profile"
        ];
      }) ss
    )
  ) (b.groupBy profileOf secrets);
  # profile-level settings (`profiles.<p>.defaults`) next to the secrets of that profile
  merged = declared // b.mapAttrs (p: v: (declared.${p} or { }) // v) profiles;
in
{
  files.file.${path}.text = toml (
    {
      inherit project;
    }
    // (if defaults == { } then { } else { inherit defaults; })
    // (if providers == { } then { } else { inherit providers; })
    // {
      profiles = merged;
    }
  );
}
