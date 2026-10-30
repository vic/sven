# the modules collected in sink `from`, as one module that imports them: the value of the sink's key that gives to a
# class sink (nixos, homeManager, darwin, any module system).
#   yen.kinds.host.sinks.age-secrets.nixos = imports { from = yen.kinds.host.sinks.age-secrets; };
{ from }:
{ sinks, ... }:
{
  imports = sinks.${from.__sink};
}
