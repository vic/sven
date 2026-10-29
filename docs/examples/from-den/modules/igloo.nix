# den.hosts.x86_64-linux.igloo.users.tux, and the igloo aspect.
{ yen, ... }:
{
  yen.host.igloo.system = "x86_64-linux";
  yen.aspects.igloo = {
    at = yen.host.igloo;
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.hello ];
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/fake";
          fsType = "auto";
        };
      };
  };
  # provides.to-users: content for the users of igloo, given at each user
  yen.aspects.igloo-users = {
    at = yen.lib.all [
      yen.kinds.user
      (yen.lib.within yen.host.igloo)
    ];
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.vim ];
      };
  };
}
