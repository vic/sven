# Den batteries are ordinary aspects here: hostname is in features/base.nix, define-user in user-account, primary-user in sini/users.nix.
{ yen, lib, ... }:
let
  inherit (yen.lib) all within has;
in
{
  yen.kinds.user.fields.shell = yen.lib.opt (yen.helpers.enum [
    "bash"
    "zsh"
    "fish"
  ]) "bash";
  yen.user.bob.shell = "fish";
  yen.aspects.user-shell = {
    # user-shell: the user's shell, enabled on the machine
    at = all [
      yen.kinds.user
      (within yen.helpers.linux)
    ];
    os =
      { user, pkgs, ... }:
      {
        programs.${user.shell}.enable = lib.mkIf (user.shell != "bash") true;
        users.users.${user.name}.shell = pkgs.${user.shell};
      };
  };
  yen.aspects.insecure = {
    at = yen.host.stage;
    os.nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];
  };
  yen.aspects.tty-autologin = {
    at = all [
      yen.user.bob
      (within yen.kinds.guest)
    ];
    os =
      { user, ... }:
      {
        services.getty.autologinUser = user.name;
      };
  };
  yen.aspects.global-pkgs = {
    # use-global-pkgs: only where home-manager has users
    at = all [
      yen.helpers.machines
      (has yen.kinds.user)
    ];
    os.home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };
  };
}
