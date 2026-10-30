#: lib.batteries.files.json :: { from; path; value ? ; } -> key value -- a repo file with the JSON of sink from
# a repo file with the JSON of sink `from` (after `value`, the identity by default) and a final newline: the value of
# a key that gives to the files sink. CI matrices, inventories, any data other tools read.
#   files = files.json { from = yen.kinds.fleet.sinks.ci; path = "ci.json"; value = builtins.attrValues; };
{
  from,
  path,
  value ? v: v,
}:
{ sinks, ... }:
{
  files.file.${path}.text = builtins.toJSON (value sinks.${from.__sink}) + "\n";
}
