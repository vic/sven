{
  title = "includes, provides and meta";
  description = "How large Den configurations are written, and the same structure in yen: features in many files, hosts that pick features, user meta.";
  section = "den";
  route = "den/includes";
  order = 1;

  body =
    { docs, ... }:
    [
      ''
        This page follows the structure of [drupol/infra](https://github.com/drupol/infra), one of the largest public
        Den configurations: ten hosts, one user on most of them, and about a hundred feature files. The same shapes
        appear in most Den configurations on GitHub.
      ''
      (docs.table
        [ "Den" "yen" ]
        [
          [
            "`den.aspects.base` written in 26 files"
            "the same: `yen.aspects.base` in many files; nothing is lost, see below"
          ]
          [
            "`den.default.includes = [ base ]`"
            "`at = yen.kinds.host` on the aspect"
          ]
          [
            "a host's `includes` or `provides.to-users.includes = [ desktop openssh … ]`"
            "the host file adds the host to each feature's `at`"
          ]
          [
            "`(den.aspects.facter ./facter.json)`, `(mount-cifs \"//nas/media\")`"
            "a host field, and one aspect whose `at` tests the field"
          ]
          [
            "`den.aspects.pol.provides.x280`, `host-aspects`"
            "an aspect at `all [ yen.user.pol (within yen.host.x280) ]`"
          ]
          [
            "`meta = { fullname; email; authorizedKeys; }`, read with `config.meta`"
            "typed user fields, read as `user.fullname` or `yen.user.pol.fullname`"
          ]
          [
            "`den.aspects.tools.provides.nix-trusted-user`"
            "an aspect with its own name"
          ]
          [
            "`hasAspect`"
            "an aspect in a predicate: `at = all [ yen.kinds.user (within yen.aspects.gnome) ]`"
          ]
        ]
      )
      (docs.file "modules/fleet.nix")
      ''
        ## One feature in many files

        Each file under `modules/base/` writes part of the `base` aspect. yen reads all of them. A NixOS module from
        each file reaches every host.
      ''
      (docs.tabs [
        {
          label = "base/nix.nix";
          body = docs.file "modules/base/nix.nix";
        }
        {
          label = "base/i18n.nix";
          body = docs.file "modules/base/i18n.nix";
        }
        {
          label = "base/host.nix";
          body = docs.file "modules/base/host.nix";
        }
      ])
      ''
        ## Hosts pick features

        In Den, a host file lists the features it includes. In yen a feature has no `at` of its own, and each host file
        adds the host to the `at` of the features it wants. `at` from several files is a union, so the list stays in the
        host file, as in Den.
      ''
      (docs.file "modules/features.nix")
      (docs.tabs [
        {
          label = "hosts/x280.nix";
          body = docs.file "modules/hosts/x280.nix";
        }
        {
          label = "hosts/rpi4.nix";
          body = docs.file "modules/hosts/rpi4.nix";
        }
      ])
      ''
        ## User meta is fields

        Den users often keep a free-form `meta` attribute set and read it back with `config.meta`. In yen these are
        fields of the user kind. A missing `fullname` is an error at the user, and every file can read the value.
      ''
      (docs.file "modules/users/pol.nix")
    ];

  checks =
    {
      result,
      eq,
      yes,
      no,
      ...
    }:
    {
      hosts = eq (builtins.attrNames result.flake.nixosConfigurations) ([
        "rpi4"
        "x280"
      ]);
    };

  e2e =
    {
      flake,
      eq,
      yes,
      no,
      ...
    }:
    let
      c = n: flake.nixosConfigurations.${n}.config;
    in
    {
      base-many-files = yes (
        builtins.all
          (
            n:
            (c n).i18n.defaultLocale == "en_GB.UTF-8"
            && builtins.elem "flakes" (c n).nix.settings.experimental-features
            && (c n).networking.hostName == n
          )
          [
            "x280"
            "rpi4"
          ]
      );
      openssh-union = {
        t1 = yes ((c "x280").services.openssh.enable);
        t2 = yes ((c "rpi4").services.openssh.enable);
      };
      desktop-x280-only = {
        t1 = yes ((c "x280").services.xserver.desktopManager.gnome.enable);
        t2 = no ((c "rpi4").services.xserver.desktopManager.gnome.enable);
      };
      shares = {
        t1 = yes ((c "x280").fileSystems ? "/mnt/media");
        t2 = no (((c "rpi4").fileSystems ? "/mnt/media"));
      };
      meta = eq ((c "rpi4").users.users.pol.description) ("Pol");
      pol-on-x280 = {
        t1 = yes (builtins.elem "dialout" (c "x280").users.users.pol.extraGroups);
        t2 = no ((builtins.elem "dialout" (c "rpi4").users.users.pol.extraGroups));
      };
    };
}
