# Den custom classes and chained forwards: a user `git` sink forwards into homeManager, which forwards into the machine's os.
# A user `maid` sink (Den hjem / maid) writes straight into the NixOS user, with no home-manager.
{ yen, lib, ... }:
{
  yen.kinds.user.sinks.git = {
    reduce = yen.lib.reduce.merge;
    homeManager =
      { git, ... }:
      { options, ... }:
      {
        programs.git = {
          enable = true;
        }
        // (if options.programs.git ? settings then { settings = git; } else { extraConfig = git; });
      };
  }; # HM 25.05: extraConfig; newer: settings
  yen.kinds.user.sinks.maid = {
    at = yen.lib.all [
      (yen.lib.within yen.helpers.linux)
      (s: lib.elem "maid" s.classes)
    ]; # only users whose `classes` list it (#26)
    os =
      { user, maid, ... }:
      {
        systemd.tmpfiles.rules = lib.mapAttrsToList (
          p: text: "f+ /home/${user.name}/${p} 0644 ${user.name} users - ${text}"
        ) (lib.foldl' (a: b: a // b) { } maid);
      };
  };
  yen.aspects.git-identity = {
    at = yen.kinds.user;
    git =
      { user, ... }:
      {
        user.name = user.name;
        user.email = "${user.name}@example.org";
      };
  };
  yen.aspects.git-defaults = {
    at = yen.kinds.user;
    git.init.defaultBranch = "main";
  };
  yen.aspects.dotfile = {
    at = yen.user.bob;
    maid.".hushlogin" = "";
  };
}
