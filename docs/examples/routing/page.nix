{
  title = "Routing and walls";
  description = "An element goes up to the nearest scope that has the sink and where the sink's `at` holds.";
  section = "behavior";
  order = 5;

  body =
    { docs, result, ... }:
    [
      ''
        An aspect does not say who receives its elements. The tree does. An element goes to the nearest
        ancestor-or-self scope that has the sink, and where the sink's `at` holds.

        This example has a fleet, two environments, two hosts, a user and a home:
      ''
      (docs.fileWith "{17,23}" "modules/fleet.nix")
      (docs.file "modules/instances.nix")
      (docs.file "modules/aspects.nix")
      (docs.value result.flake)
      (docs.table
        [ "Element" "Given at" "Received at" "Why" ]
        [
          [
            "`os`"
            "user `alice`"
            "host `web`"
            "a user has no `os` sink; the host above has one"
          ]
          [
            "`os`"
            "home `bob`"
            "home `bob`"
            "the home has its own `os` sink: ancestor-or-self"
          ]
          [
            "`dns`"
            "host `web`"
            "environment `prod`"
            "`prod` is public, so its `dns` sink holds"
          ]
          [
            "`dns`"
            "host `box`"
            "fleet `main`"
            "`lab` is not public; the next receiver is the fleet"
          ]
        ]
      )
      ''
        The routes, drawn from `result.graph.edges`:
      ''
      (docs.routes result)
      ''
        ## Walls

        A sink with no keys is a wall. It receives elements and gives nothing on. A home under a host
        can keep its packages away from the host:
      ''
      (docs.file "modules/walls.nix")
      ''
        `result.reduced.packages` shows both receivers. Only the host gives its packages to the flake:
      ''
      (docs.value result.reduced.packages)
      (docs.note "A sink nobody reads" ''
        A sink that nobody reads is not an error. Nothing happens. Laziness means it costs nothing either.
      '')
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      flake = eq (result.flake) ({
        dns = {
          fleet = [ "box A" ];
          prod = [ "web A" ];
        };
        os = {
          bob = [ "account bob" ];
          web = [ "account alice" ];
        };
        packages.web = [ "vim for alice" ];
      });
      wall = eq (result.reduced.packages."fleet:main/environment:prod/host:web/home:bob") ([
        "vim for bob"
      ]);
    };
}
