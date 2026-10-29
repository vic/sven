{
  title = "Flake outputs";
  description = "The root's `out` sink is the flake. Any element can read the outputs with the `out` arg.";
  section = "concepts";
  order = 14;

  body =
    { docs, r, ... }:
    [
      ''
        yen does not know what a flake is. The root kind declares an `out` sink with `merge`, and `yen.flake`
        gives the flake's outputs. Each sink with an `out` key gives its part.
      ''
      (docs.fileWith "{6,12}" "modules/fleet.nix")
      ''
        ## Read the outputs

        The `out` arg is the flake itself, read lazily. An element can build on other outputs without `inputs.self`:
      ''
      (docs.fileWith "{7}" "modules/aspects.nix")
      (docs.value r.flake)
      ''
        ## With or without flakes

        `(import yen).lib.mkFlake module` gives the flake outputs. `(import yen).lib.eval module` gives every query,
        and `flake` is one of them. `mkFlake m` is `(eval m).flake`.
      ''
      (docs.note "Laziness closes the loop" ''
        `inventory` reads `out` and gives to `out`. There is no fixpoint to run: Nix computes a value only when something reads it,
        and `inventory` never reads itself.
      '')
    ];

  checks =
    { r, ... }:
    {
      flake =
        r.flake == {
          inventory = [
            "postgres"
            "nginx"
          ];
          services = {
            db = [ "postgres" ];
            web = [ "nginx" ];
          };
        };
    };
}
