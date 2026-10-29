# Per-aspect flake inputs (flake-file) and module imports. vm-host: a host that has a guest.
{ yen, inputs, ... }:
{
  yen.aspects.secrets = {
    at = yen.kinds.host;
    nixos.imports = [ inputs.agenix.nixosModules.default ];
    flake-file.inputs.agenix.url = "github:ryantm/agenix";
  };
  yen.aspects.vm = {
    at = yen.kinds.guest;
    nixos.imports = [ inputs.microvm.nixosModules.microvm ];
    flake-file.inputs.microvm.url = "github:microvm-nix/microvm.nix";
  };
  yen.aspects.vm-host = {
    at = yen.lib.all [
      yen.kinds.host
      (yen.lib.has yen.kinds.guest)
    ];
    nixos.imports = [ inputs.microvm.nixosModules.host ];
  };
}
