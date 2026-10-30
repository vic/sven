#: lib.batteries.secrets.sops-config :: { from; path ? ; } -> key value -- .sops.yaml from the creation rules of sink from
# .sops.yaml from sink `from`: each element a creation rule `{ path_regex; key_groups ? ; age ? ; … }`. The value of a
# key that gives to the files sink.
#   files = secrets.sops-config { from = yen.kinds.fleet.sinks.sops-rules; };
{
  from,
  path ? ".sops.yaml",
}:
{ sinks, ... }:
{
  files.file.${path}.text = import ../github/yaml.nix { creation_rules = sinks.${from.__sink}; };
}
