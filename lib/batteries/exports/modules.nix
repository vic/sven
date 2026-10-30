#: lib.batteries.exports.modules :: { from; output; } -> out value -- the modules of sink from as <output>.<scope name> for other flakes
# aspects used outside yen: the modules collected in sink `from` at this scope become `<output>.<scope name>` (for
# example `nixosModules`, `homeModules`, `darwinModules`) for other flakes. The value of the sink's `out` key.
#   yen.kinds.export.sinks.os.out = exports.modules { from = yen.kinds.export.sinks.os; output = "nixosModules"; };
{ from, output }:
{ scope, sinks, ... }:
{
  ${output}.${scope.name}.imports = sinks.${from.__sink};
}
