{
  title = "Bundles of the library";
  description = "A bundle is a kit whose assemblies make more assemblies: base for a new machine, homelab for a server and its nodes.";
  section = "batteries";
  route = "batteries/kits-bundles";
  order = 6;

  body =
    {
      docs,
      result,
      variant,
      ...
    }:
    let
      members = import ./members.nix result;
    in
    [
      ''
        A bundle is a kit whose `adds` make several assemblies, each on machines taken from the bundle's own roles.

        | Bundle | Roles | Adds |
        |---|---|---|
        | `base` | `default` with `device`, `layout` (a ref), `authorizedKeys`, `hardware` | disko, facter, emergency-access, and sshd as server, on the same machines. No users: a user needs a name per machine |
        | `homelab` | `server` (exactly 1), `node`; the settings of `base` and `prefix` | base on both roles; wireguard (server controller, nodes peers); borg (server backs up); monitoring (server scrapes); dns on the server |

        The engine adds one level, so `homelab` also lists what `base` and `borg` add. A role's `settings` may be a
        function of the machine, for a device per machine. You import the kits a bundle uses, then write one assembly:
      ''
      (docs.file "modules/assemblies.nix")
      (docs.file "modules/fleet.nix")
      ''
        ## The result

        The members of each machine (the assemblies the bundle added are named `lab-...`):
      ''

      (docs.value (
        builtins.listToAttrs (
          map
            (m: {
              name = m;
              value = members.of m;
            })
            [
              "lb"
              "web"
              "nas"
            ]
        )
      ))
      ''
        What the members export:
      ''
      (docs.value members.exports)
      ''
        ## The contract

        `homelab` allows exactly one server. Two:
      ''
      (docs.file "variants/two-servers.nix")
      (docs.value (map (e: e.error) (variant "variants/two-servers.nix").errors))
      ''
        And none:
      ''
      (docs.file "variants/no-server.nix")
      (docs.value (map (e: e.error) (variant "variants/no-server.nix").errors))
    ];

  checks = import ./checks.nix;
}
