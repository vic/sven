{
  title = "Network kits";
  description = "Ready-made kits from yen.lib.kits: wireguard, zerotier and dns, with battery addresses.";
  section = "batteries";
  route = "batteries/kits-network";
  order = 5;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    [
      ''
        `yen.lib.kits` holds kits written as modules, so a fleet writes only assemblies. A kit that reads public values
        takes `{ root; }`, the directory of the vars. Battery `addresses` gives each member an address of a prefix, in
        member order; a repeated address, a prefix that is no IPv4 /16 to /24 and a prefix too small are error records.

        | Kit | Roles | Interface | Does |
        |---|---|---|---|
        | `wireguard { root; }` | `controller` (exactly 1), `peer` | `prefix`, `port` (51820) | an address per member; keys by generators; the private key is a path, never in the store; a peer talks to the controller |
        | `zerotier { root; }` | `controller` (1), `moon` (0 to 4), `peer` | none | the controller's network id and the moons' ids are public generator files; peers join and list the moons |
        | `dns` | `default` | none | a record for every `endpoints` any kit exports |

        This is the fleet's own words, and the assemblies:
      ''
      (docs.file "modules/network.nix")
      ''
        Each wireguard member has an address in member order, and a peer sees only the controller:
      ''
      (docs.value result.flake.config)
      ''
        dns reads the endpoints that `site` exports:
      ''
      (docs.value result.flake.cnames)
      ''
        ## The contract

        A wireguard or zerotier network needs exactly one controller, zerotier allows four moons at most, and a prefix
        must hold its members.
      ''
      (docs.file "variants/five-moons.nix")
      (docs.value (map (e: e.error) (variant "variants/five-moons.nix").errors))
      (docs.value (map (e: e.error) (variant "variants/no-controller.nix").errors))
      (docs.value (map (e: e.error) (variant "variants/two-controllers.nix").errors))
      (docs.value (map (e: e.error) (variant "variants/small-prefix.nix").errors))
      ''
        The members of one wireguard assembly must name the same prefix, and every member needs its public file in
        `vars`. A missing file is an error record, never a text in the configuration:
      ''
      (docs.file "variants/prefix-differs.nix")
      (docs.value (map (e: e.error) (variant "variants/prefix-differs.nix").errors))
      (docs.file "variants/missing-public.nix")
      (docs.value (map (e: e.error) (variant "variants/missing-public.nix").errors))
    ];

  checks = import ./checks.nix;
}
