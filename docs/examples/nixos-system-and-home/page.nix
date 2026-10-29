{
  title = "System and home in one feature";
  description = "One feature with NixOS and home-manager parts: no sharedModules, no extraSpecialArgs, no mkIf on the platform.";
  section = "nixos";
  route = "nixos/system-and-home";
  order = 2;

  body =
    { docs, ... }:
    [
      ''
        A feature such as a desktop often has two parts: system configuration, and home-manager configuration for each
        user. The usual answers each have a cost:

        - `home-manager.sharedModules` in the NixOS module. It does not work for standalone home-manager, and a
          module that is imported from two features is added two times.
        - `extraSpecialArgs` to give home-manager the values that NixOS gets from `specialArgs`. You write them two
          times, and standalone home-manager needs a third copy.
        - `osConfig ? null` and `lib.mkIf (osConfig != null)`, because `osConfig` does not exist in standalone mode.
        - `lib.mkIf pkgs.stdenv.isLinux` to send a package list to the system on one machine and to the home on
          another. A `mkIf` around `imports` causes infinite recursion.

        In yen, the feature is aspects. `at` says where each part goes. A user's home-manager content goes into each
        NixOS host that the user lives on. A standalone home builds its own `homeConfigurations` output.
      ''
      (docs.tabs [
        {
          label = "fleet.nix";
          body = docs.file "modules/fleet.nix";
        }
        {
          label = "machines.nix";
          body = docs.file "modules/machines.nix";
        }
      ])
      ''
        ## Two levels: the desktop and its users

        This is the *multi context aspect* of the
        [dendritic design guide](https://github.com/Doc-Steve/dendritic-design-with-flake-parts/wiki/Dendritic_Aspects).
        The home part is not a private module that the system part imports. It is an aspect at the users of every host
        that has the desktop. Two features that both need it do not import it two times: an aspect is given once per
        scope.
      ''
      (docs.file "modules/gnome.nix")
      ''
        ## The same concern, a different level per machine

        On NixOS, fonts are system packages. On the work laptop there is no NixOS, so they go into the home. The two
        aspects have different `at`. No module looks at `pkgs.stdenv` to find out where it is.
      ''
      (docs.file "modules/fonts.nix")
      ''
        ## Values for home-manager

        A home-manager module gets the same yen args as a NixOS module: the host, the user, and any sink. There is
        no `extraSpecialArgs`. To read the host's *NixOS options* from home-manager, see
        [osConfig in home-manager](/recipes/os-config/).
      ''
      (docs.file "modules/args.nix")
      (docs.note "What the checks prove" ''
        The desk has GNOME, and ana's home on the desk has its settings. Her home on the work laptop has neither.
        Fonts are system packages on the desk, and home packages on the laptop, and never both.
      '')
    ];

  checks =
    { result, ... }:
    {
      outputs =
        builtins.attrNames result.flake.nixosConfigurations == [ "desk" ]
        && builtins.attrNames result.flake.homeConfigurations == [ "ana@work" ];
    };

  e2e =
    { flake, ... }:
    let
      desk = flake.nixosConfigurations.desk.config;
      onDesk = desk.home-manager.users.ana;
      work = flake.homeConfigurations."ana@work".config;
      names = ps: map (p: p.pname or p.name) ps;
      iface = c: c.dconf.settings ? "org/gnome/desktop/interface";
    in
    {
      gnome = desk.services.xserver.desktopManager.gnome.enable;
      gnome-home = iface onDesk && !(iface work);
      fonts-system = builtins.elem "inter" (names desk.fonts.packages);
      fonts-home = builtins.elem "inter" (names work.home.packages);
      fonts-once = !(builtins.elem "inter" (names onDesk.home.packages));
      prompt =
        onDesk.home.sessionVariables.PROMPT_TAG == "ana@desk" && !(work.home.sessionVariables ? PROMPT_TAG);
    };
}
