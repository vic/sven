# den.batteries.insecure: nixpkgs.config does not merge lists. When two modules set permittedInsecurePackages,
# only one list survives. A sink collects the names, and one module sets the option.
{ yen, lib, ... }:
{
  yen.kinds.host.sinks.insecure.nixos =
    { insecure, ... }:
    {
      nixpkgs.config.permittedInsecurePackages = lib.flatten insecure;
    };

  yen.aspects.matrix-client = {
    at = yen.host.box;
    insecure = [ "olm-3.2.16" ];
  };
  yen.aspects.old-tool = {
    at = yen.user.bob; # from a user: the names go up to each of bob's hosts
    insecure = [ "python-2.7.18.8" ];
  };
}
