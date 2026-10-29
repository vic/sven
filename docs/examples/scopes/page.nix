{
  title = "Scopes and spawns";
  description = "A scope is one instance at one place in a tree. `spawns` builds the tree from your data.";
  section = "concepts";
  order = 5;

  body =
    { docs, result, ... }:
    [
      ''
        A scope is one instance at one place in the tree. The root kind is the kind that no kind spawns.
        `spawns.<kind>` is a function of the parent scope. It gives the instances that live under it.
      ''
      (docs.fileWith "{7,8,11}" "modules/tree.nix")
      (docs.file "modules/instances.nix")
      ''
        The tree comes from the data. Nothing lists the children by hand:
      ''
      (docs.scopes result)
      ''
        ## Identity is a path

        The id of a scope is its path: `fleet:main/environment:prod/host:web/user:alice`.
        One instance can live in several places. `alice` has two scopes, one under each of her hosts.
        Names need not be unique.

        `result.scopes` gives the scopes in order:
      ''
      (docs.value (map (s: s.id) result.scopes))
      ''
        ## Order

        A parent comes before its children. Siblings sort by the `order` sink (default `0`), then by name.
        `web` comes before `db` because of this aspect:
      ''
      (docs.file "modules/order.nix")
      (docs.aside "tip" "Kinds without scopes" ''
        A kind that no kind spawns is data: its instances have no scope, and refs to them still work.
        See [Instances and refs](/concepts/instances-refs/#data-kinds).
      '')
      ''
        ## Read the tree inside the fleet

        `yen.lib.graph` is readable by any module. This example gives its scope ids as a flake output:
      ''
      (docs.file "modules/outputs.nix")
    ];

  checks =
    { result, ... }:
    {
      alice-twice = builtins.length (builtins.filter (s: s.name == "alice") result.scopes) == 2;
      web-before-db = builtins.elemAt (map (s: s.name) result.scopes) 5 == "web";
      flake = result.flake.scopes == map (s: s.id) result.scopes;
    };
}
