# A component: it reads sources (the tree, the sinks) and writes sinks. It gives 0 to n elements.
{ yen, ... }:
{
  yen.aspects.vm-network = {
    at = yen.lib.has yen.kinds.guest; # every host with a guest
    cycle =
      { tree, ... }:
      {
        tree = [
          {
            category = "vms";
            children = yen.kinds.guest;
          }
        ]; # a request: the guest children
        bridges = map (g: "br-${g.name}") (builtins.head (tree.select "vms")); # one element per guest
        errors = [ ];
      };
  };
}
