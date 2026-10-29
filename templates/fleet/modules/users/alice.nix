{ yen, ... }:
{
  yen.user.alice = {
    groups = [ yen.group.ops ];
    phone = true;
  };
  yen.aspects.alice-account = {
    at = yen.user.alice;
    account =
      { lib, ... }:
      {
        description = lib.mkDefault "Alice";
      };
  }; # class lib, not yen's
}
