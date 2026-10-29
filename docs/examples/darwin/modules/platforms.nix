# Two kinds of machine, one `os` sink: an aspect writes `os` once, and each platform forwards it.
{ yen, inputs, ... }:
{
  yen.kinds.fleet = {
    spawns = {
      host = _: yen.host;
      mac = _: yen.mac;
    };
    sinks.out.reduce = yen.lib.reduce.merge;
  };
  yen.kinds.host.sinks = {
    os.nixos =
      { os, ... }:
      {
        imports = os;
      };
    nixos.out =
      { host, nixos, ... }:
      {
        nixosConfigurations.${host.name} = inputs.nixpkgs.lib.nixosSystem { modules = nixos; };
      };
  };
  yen.kinds.mac.sinks = {
    os.darwin =
      { os, ... }:
      {
        imports = os;
      };
    darwin.out =
      { mac, darwin, ... }:
      {
        darwinConfigurations.${mac.name} = inputs.nix-darwin.lib.darwinSystem { modules = darwin; };
      };
  };

  yen.fleet.main = { };
  yen.flake = { out, ... }: out;
}
