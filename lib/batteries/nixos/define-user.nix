#: lib.batteries.nixos.define-user :: { scope; } -> module -- an account named after the scope
# an account named after the scope (Den's define-user)
{ scope, ... }:
{
  users.users.${scope.name} = {
    isNormalUser = true;
    home = "/home/${scope.name}";
  };
}
