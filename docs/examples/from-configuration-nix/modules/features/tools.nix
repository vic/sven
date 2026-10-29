# `pkgs` stays open: NixOS fills it.
{ yen, ... }:
{
  yen.aspects.tools = {
    at = yen.kinds.host;
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          git
          vim
        ];
      };
  };
}
