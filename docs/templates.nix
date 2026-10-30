# Every example with a flake.nix is a flake template (yen.lib.batteries.docs.templates). Pure and cheap: no inputs,
# no yen evaluation. Both flakes use it: docs/flake.nix and the repository root flake.nix.
import ../lib/batteries/docs/templates.nix {
  root = ./examples;
  description = d: (import (d + "/page.nix")).description;
}
