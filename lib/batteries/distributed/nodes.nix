#: lib.batteries.distributed.nodes :: { from; } -> key value -- each machine imports the modules other scopes wrote for it
# distributed config (oddlama's `nodes.<name>`): any scope gives `{ <machine> = module; }` to sink `from`
# (reduce entries); each machine imports the modules written for it.
#   nixos = distributed.nodes { from = yen.kinds.fleet.sinks.nodes; };
{ from }:
{ scope, sinks, ... }:
{
  imports = builtins.concatMap (
    e: if e.value ? ${scope.name} then [ e.value.${scope.name} ] else [ ]
  ) sinks.${from.__sink};
}
