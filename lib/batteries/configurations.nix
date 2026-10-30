# one flake output per scope: `<output>.<scope name> = build scope modules`, the modules collected in sink `from`.
# The value of the sink's `out` key. nixosConfigurations, darwinConfigurations, homeConfigurations, any builder.
#   out = configurations { from = yen.kinds.host.sinks.nixos; output = "nixosConfigurations";
#     build = _: modules: nixpkgs.lib.nixosSystem { inherit modules; }; };
{
  from,
  output,
  build,
}:
{ scope, sinks, ... }:
{
  ${output}.${scope.name} = build scope sinks.${from.__sink};
}
