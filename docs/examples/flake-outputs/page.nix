{
  title = "Flake outputs";
  description = "The root's `out` sink is the flake. Any element can read the outputs with the `out` arg.";
  section = "behavior";
  order = 8;

  body =
    { docs, result, ... }:
    [
      ''
        yen does not know what a flake is. The root kind declares an `out` sink with `merge`, and `yen.flake`
        gives the flake's outputs. Each sink with an `out` key gives its part.
      ''
      (docs.fileWith "{6,8-11}" "modules/fleet.nix")
      ''
        ## Read the outputs

        The `out` arg is the flake itself, read lazily. An element can build on other outputs without `inputs.self`:
      ''
      (docs.fileWith "{12-18}" "modules/aspects.nix")
      (docs.value result.flake)
      ''
        ## With or without flakes

        `(import yen).lib.mkFlake sinks module` gives the flake outputs. `(import yen).lib.eval module` gives every query,
        and `flake` is one of them. Each key of `sinks` is a module sink: `mkFlake sinks m` is the `flake` of a root module
        that imports `sinks` and `m`, and declares each key of `sinks` in `yen.sinks`.
      ''
      (docs.note "Laziness closes the loop" ''
        `inventory` reads `out` and gives to `out`. There is no fixpoint to run: Nix computes a value only when something reads it,
        and `inventory` never reads itself.
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
        inventory = [
          "postgres"
          "nginx"
        ];
        services = {
          db = [ "postgres" ];
          web = [ "nginx" ];
        };
      });
    };
}
