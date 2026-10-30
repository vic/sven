# colmenaHive from sink `from` (reduce merge: `{ <host> = module; }` per host): the value of the sink's `out` key.
#   out = deploy.colmena { from = yen.kinds.fleet.sinks.colmena; inherit (inputs.colmena.lib) makeHive;
#     meta.nixpkgs = inputs.nixpkgs.legacyPackages.x86_64-linux; };
{
  from,
  makeHive,
  meta ? { },
}:
{ sinks, ... }:
{
  colmenaHive = makeHive ({ inherit meta; } // sinks.${from.__sink});
}
