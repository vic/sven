# Den: deterministic ids from sorted names (no state). Each host gets its own ssh port.
{ yen, ... }:
let
  whole.graph = true; # a tree request: the whole fleet (the ids read every host scope)
in
{
  yen.aspects.ssh-port = {
    at = yen.kinds.host;
    cycle =
      { tree, scope, ... }:
      {
        tree = [ whole ];
        nixos = [
          {
            services.openssh.enable = true;
            services.openssh.ports = [
              (2200 + (yen.helpers.ids (builtins.head (tree.select whole))).${scope.name})
            ];
          }
        ];
      };
  };
}
