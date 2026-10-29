{ yen, ... }:
{
  yen.aspects.primary-user.nixos =
    { user, ... }:
    {
      users.users.${user.name}.extraGroups = [
        "wheel"
        "networkmanager"
      ];
    };
}
