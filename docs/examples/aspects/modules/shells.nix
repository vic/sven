{ yen, ... }:
{
  # active at hosts and at users; static content lands once at each receiver
  yen.aspects.zsh = {
    at = [
      yen.kinds.host
      yen.kinds.user
    ];
    packages = "zsh";
  };
  # content that names the scope lands once per scope
  yen.aspects.dotfiles = {
    at = yen.kinds.user;
    packages = { user, ... }: "dotfiles-${user.name}";
  };
}
