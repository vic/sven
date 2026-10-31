#: lib.kits.emergency-access :: { yen, lib, ... } -> module -- kit emergency-access: root logs in with a key or a password, only where a member is
# role `default`, interface `authorizedKeys` (list of str, public keys: data, no default). Each machine that holds a
# member gets `users.users.root.openssh.authorizedKeys.keys` and a root password hash, a secret generated for that
# machine (`emergency-root/hash`, users stage). A machine without a member is untouched.
#   imports = [ inputs.yen.lib.kits.emergency-access ];
{ yen, lib, ... }:
{
  yen.kit.emergency-access.roles.default.interface.authorizedKeys.type =
    lib.types.listOf lib.types.str;

  yen.aspects.kit-emergency-access = {
    at = yen.lib.all [
      yen.kinds.member
      (s: yen.lib.same (s.kit or null) yen.kit.emergency-access)
    ];
    nixos =
      { member, ... }:
      {
        users.users.root = {
          openssh.authorizedKeys.keys = member.settings.authorizedKeys;
          hashedPasswordFile = "/run/secrets-for-users/vars/emergency-root/hash";
        };
      };
    generators =
      { member, ... }: # `member` makes it a function: one run per machine
      {
        name = "emergency-root";
        files.hash = {
          secret = true;
          neededFor = "users";
        };
      };
  };
}
