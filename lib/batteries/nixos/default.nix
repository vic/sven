# NixOS batteries. NixOS is the target domain, not a yen word: you write every yen key, a battery is the value.
# A battery that reads a sink takes the sink as a ref (`from`), never its name.
{
  system = import ./system.nix;
  hostname = import ./hostname.nix;
  define-user = import ./define-user.nix;
  primary-user = import ./primary-user.nix;
  unfree = import ./unfree.nix;
  insecure = import ./insecure.nix;
}
