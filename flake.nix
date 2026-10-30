{
  outputs = _: {
    inherit (import ./.) lib;
    templates = import ./docs/templates.nix;
    # the engine suites, for github:denful/fastest: nix run github:denful/fastest#fastest -- --flake .#tests
    inherit (import ./tests) tests;
  };
}
