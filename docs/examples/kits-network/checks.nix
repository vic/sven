{
  result,
  variant,
  eq,
  yes,
  ...
}:
let
  msgs = f: map (e: e.error) (variant f).errors;
  has = f: re: builtins.any (m: builtins.match re m != null) (msgs f);
in
{
  addresses = eq (result.flake.config.lb.networking.wireguard.interfaces.vpn.ips) [ "10.8.0.2/32" ];
  peers =
    eq (map (p: p.allowedIPs) result.flake.config.lb.networking.wireguard.interfaces.vpn.peers)
      [
        [ "10.8.0.1/32" ]
        [ "10.8.0.3/32" ]
      ];
  dns = eq result.flake.cnames [
    {
      name = "www.example.org";
      target = "web";
    }
  ];
  five-moons = yes (
    has "variants/five-moons.nix" ".*assembly crowd role moon: [0-9]+ machines, at most 4"
  );
  no-controller = yes (
    has "variants/no-controller.nix" ".*assembly headless role controller: 0 machines, at least 1"
  );
  two-controllers = yes (
    has "variants/two-controllers.nix" ".*assembly twin role controller: [0-9]+ machines, at most 1"
  );
  small-prefix = yes (
    has "variants/small-prefix.nix" ".*addresses: 10.8.0.0/30 is not an IPv4 prefix.*"
  );
  prefix-differs = yes (
    has "variants/prefix-differs.nix" "wireguard: assembly split members disagree on prefix"
  );
  missing-public = yes (
    has "variants/missing-public.nix" "wireguard: lb has no wg-lost.pub public key"
  );
}
