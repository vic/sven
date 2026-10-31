#: lib.kits.users :: { yen, lib, ... } -> module -- kit users: one login user per assembly, its password hash a secret on that machine only
# role `default`, interface `user` (str), `groups` (list of str, default none), `shell` (a function from pkgs to a
# package, default bash: the fleet has no package ref, so a function of pkgs stands for it). Each member generates
# `user-<user>/hash`, a secret for the users stage, on the machine of that member and no other. Two assemblies for
# one user on one machine are an error. Needs the fleet's `exports` and `generators` sinks.
#   imports = [ inputs.yen.lib.kits.users ];
{ yen, lib, ... }:
let
  inherit (yen.lib) all same;
  at = all [
    yen.kinds.member
    (s: same (s.kit or null) yen.kit.users)
  ];
  user = s: if builtins.isString s.settings.user then s.settings.user else null; # settings-typed reports the rest
in
{
  yen.kit.users = {
    roles.default.interface = {
      user.type = lib.types.str;
      groups = {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      shell = {
        type = lib.types.functionTo lib.types.package;
        default = pkgs: pkgs.bashInteractive;
      };
    };
    exports = [ "user" ];
  };

  # the shell is its own aspect: it needs `pkgs`, which only the NixOS module system answers
  yen.aspects.kit-users-shell = {
    inherit at;
    nixos =
      { member, pkgs, ... }:
      {
        users.users.${member.settings.user}.shell = member.settings.shell pkgs;
      };
  };
  yen.aspects.kit-users = {
    inherit at;
    nixos =
      { member, ... }:
      let
        s = member.settings;
      in
      {
        users.users.${s.user} = {
          isNormalUser = true;
          extraGroups = s.groups;
          hashedPasswordFile = "/run/secrets-for-users/vars/user-${s.user}/hash";
        };
      };
    generators =
      { member, ... }:
      if user member == null then
        null
      else
        {
          name = "user-${user member}";
          files.hash = {
            secret = true;
            neededFor = "users";
          };
        };
    exports = { member, ... }: lib.optionalAttrs (user member != null) { user = user member; };
    errors =
      {
        member,
        scope,
        exports,
        ...
      }:
      map
        (
          e:
          "users: ${user member} is set by assemblies ${member.assembly.name} and ${e.assembly.name} on ${scope.parent.name}"
        )
        (
          lib.filter (
            e:
            user member != null
            && same e.machine scope.parent
            && (e.value.user or null) == user member
            && e.assembly.name > member.assembly.name
          ) exports
        );
  };
}
