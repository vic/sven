# terraformConfigurations.<name> (github:terranix/terranix) from the modules of sink `from`. `name` reads the scope.
#   out = terranix.configuration { from = yen.kinds.env.sinks.terraform; inherit (inputs.terranix.lib) terranixConfiguration;
#     system = "x86_64-linux"; };
{
  from,
  terranixConfiguration,
  system,
  name ? s: s.name,
}:
{ scope, sinks, ... }:
{
  terraformConfigurations.${name scope} = terranixConfiguration {
    inherit system;
    modules = sinks.${from.__sink};
  };
}
