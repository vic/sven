{
  yen.aspects.base.nixos =
    { host, ... }:
    {
      networking.hostName = host.name;
      nixpkgs.hostPlatform = host.system;
      system.stateVersion = "25.05";
    };
}
