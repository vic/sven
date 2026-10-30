# one repo file from the texts of a sink, joined in its order: the value of a key that gives to the files sink.
# With `reduce = yen.lib.batteries.ordered` on `from`, sections from any file go where their before and after say.
#   files = files.document { from = yen.kinds.repo.sinks.readme; path = "README.md"; };
{
  from,
  path,
  separator ? "\n",
}:
{ sinks, ... }:
{
  files.file.${path}.text = builtins.concatStringsSep separator sinks.${from.__sink};
}
