# One of each: a NixOS host with a guest, a mac, a phone, and a standalone home. ana is on the host and the mac.
{ yen, inputs, ... }:
let
  nixos = yen.lib.batteries.nixos;
  darwin = yen.lib.batteries.darwin;
in
{
  yen.host.server.system = "x86_64-linux";
  yen.guest.ci = {
    on = yen.host.server;
    system = "x86_64-linux";
  };
  yen.mac.studio.system = "aarch64-darwin";
  yen.phone.pixel.system = "aarch64-linux";
  yen.user.ana.on = [
    yen.host.server
    yen.mac.studio
  ];
  yen.home.ana-laptop = {
    user = yen.user.ana;
    system = "x86_64-linux";
  };

  yen.aspects.server = {
    at = yen.host.server;
    nixos = {
      imports = [
        (yen.lib.batteries.home-manager.module inputs.home-manager.nixosModules.home-manager) # useGlobalPkgs too
        inputs.microvm.nixosModules.host
      ];
      boot.loader.grub.device = "nodev";
      fileSystems."/" = {
        device = "/dev/sda1";
        fsType = "ext4";
      };
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "25.05";
    };
  };
  yen.aspects.hostname = {
    at = [
      yen.kinds.host
      yen.kinds.guest
    ];
    nixos = nixos.hostname;
  };
  yen.aspects.guest = {
    at = yen.kinds.guest;
    nixos = {
      imports = [ inputs.microvm.nixosModules.microvm ];
      system.stateVersion = "25.05";
    };
  };
  yen.aspects.studio = {
    at = yen.mac.studio;
    darwin = {
      imports = [ inputs.home-manager.darwinModules.home-manager ];
      system.stateVersion = 6;
    };
  };
  yen.aspects.mac-owner = {
    at = yen.mac.studio;
    darwin = darwin.primary-user { user = _: "ana"; };
  };
  yen.aspects.brew = {
    at = yen.mac.studio;
    brew.casks = [ "firefox" ];
  };
  yen.kinds.mac.sinks.brew.darwin = darwin.homebrew { from = yen.kinds.mac.sinks.brew; };
  yen.aspects.pixel = {
    at = yen.phone.pixel;
    droid.system.stateVersion = "24.05";
    homeManager = {
      home.stateVersion = "24.05";
      programs.git.enable = true;
    };
  };
  # ana's accounts: a user has no nixos or darwin sink, so these go up to each machine she is on
  yen.aspects.accounts = {
    at = yen.kinds.user;
    nixos = nixos.define-user;
    darwin =
      { scope, ... }:
      {
        users.users.${scope.name}.home = "/Users/${scope.name}";
      };
  };
  # ana's home: inside the host and the mac, and standalone on her laptop
  yen.aspects.ana-home = {
    at = [
      yen.user.ana
      yen.home.ana-laptop
    ];
    homeManager = {
      home.stateVersion = "25.05";
      programs.git.enable = true;
    };
  };
  yen.aspects.standalone = {
    at = yen.kinds.home;
    homeManager =
      { home, ... }:
      {
        home.username = home.user.name;
        home.homeDirectory = "/home/${home.user.name}";
      };
  };
}
