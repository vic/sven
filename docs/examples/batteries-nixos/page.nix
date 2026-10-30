{
  title = "NixOS batteries";
  description = "yen.lib.batteries.nixos: system, accounts, shells, autologin, unfree, firewall, hosts, builders, persist, facter. NixOS options are the domain; yen keys are yours.";
  section = "batteries";
  route = "batteries/nixos";
  order = 3;

  body =
    { docs, ... }:
    [
      ''
        `yen.lib.batteries.nixos` holds the NixOS rules that most fleets write. NixOS is the domain of these batteries:
        they set NixOS options. They still name no yen kind, sink or aspect. You write `yen.kinds.host`, the `nixos` and
        `unfree` sinks and every aspect, in your own words.

        | Battery | Value of | Den |
        |---|---|---|
        | `system { from; nixpkgs; }` | the `out` key of the sink that collects NixOS modules | the `den.hosts` schema |
        | `hostname` | a NixOS key of an aspect | `den.batteries.hostname` |
        | `define-user` | a NixOS key of an aspect | `den.batteries.define-user` |
        | `primary-user` | a NixOS key of an aspect | `den.batteries.primary-user` |
        | `unfree { from; }` | the NixOS key of a sink of package names | `den.batteries.unfree` |
        | `insecure { from; }` | the NixOS key of a sink of package names | `den.batteries.insecure` |
        | `user-shell { shell; }` | a NixOS key; `shell` reads the scope | `den.batteries.user-shell` |
        | `autologin { user; }` | a NixOS key; `user` reads a ref or a name | `den.batteries.tty-autologin` |
        | `firewall { from; }` | the NixOS key of a sink of ports (`22` or `{ tcp; udp; }`) | quirks `firewall` |
        | `hosts { from; }` | a NixOS key; /etc/hosts and known_hosts of the other machines (`mesh`) | sini hostsfile |
        | `remote-builders { from; systemOf; }` | a NixOS key; `nix.buildMachines` of the other machines (`mesh`) | sini remote-build-client |
        | `persist { from; root; }` | the NixOS key of a sink of paths (impermanence) | quirks `persist` |
        | `facter { report; module; }` | a NixOS key, at hosts that have a report | `den.aspects.facter` |
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/aspects.nix")
      (docs.file "modules/machines.nix")
      (docs.file "modules/network.nix")
      (docs.file "modules/storage.nix")
      ''
        Each battery is a few lines. The pages [Every Den battery](/den/batteries/) and
        [Unfree packages from many files](/nixos/unfree/) write the same rules by hand. When a battery does not fit your
        fleet, copy those lines and change them: see [Write your own](/batteries/generic/#write-your-own).
      ''
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
        "desk"
        "nas"
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
      c = flake.nixosConfigurations.desk.config;
      nas = flake.nixosConfigurations.nas.config;
      ok = p: (builtins.tryEval flake.nixosConfigurations.desk.pkgs.${p}.drvPath).success;
    in
    {
      hostname = eq (c.networking.hostName) ("desk");
      accounts = {
        t1 = yes (c.users.users.ana.isNormalUser);
        t2 = eq (c.users.users.bob.home) ("/home/bob");
      };
      admin = {
        t1 = yes (builtins.elem "wheel" c.users.users.ana.extraGroups);
        t2 = no ((builtins.elem "wheel" c.users.users.bob.extraGroups));
      };
      unfree = {
        t1 = yes (ok "steam-unwrapped");
        t2 = yes (ok "vscode");
        t3 = no ((ok "zoom-us"));
      };
      insecure = eq (c.nixpkgs.config.permittedInsecurePackages) ([ "olm-3.2.16" ]);
      shell = {
        t1 = eq (c.users.users.ana.shell.pname) ("fish");
        t2 = yes (c.programs.fish.enable);
        t3 = yes (c.users.users.bob.shell.pname != "fish");
      };
      autologin = {
        t1 = eq (c.services.getty.autologinUser) ("ana");
        t2 = eq (nas.services.getty.autologinUser) (null);
      };
      firewall = {
        t1 = yes (builtins.elem 53 nas.networking.firewall.allowedUDPPorts);
        t2 = yes (builtins.elem 22 c.networking.firewall.allowedTCPPorts);
        t3 = no ((builtins.elem 53 c.networking.firewall.allowedTCPPorts));
      };
      hosts = {
        t1 = eq (c.networking.hosts."10.0.0.1") ([ "nas" ]);
        t2 = no ((c.networking.hosts ? "10.0.0.2"));
        t3 = eq (builtins.attrNames c.programs.ssh.knownHosts) ([ "nas" ]);
      };
      persist = {
        t1 = yes (c.environment.persistence."/persist".directories != [ ]);
        t2 = yes (
          builtins.elem "/etc/ssh/ssh_host_ed25519_key" (
            map (f: f.file) c.environment.persistence."/persist".files
          )
        );
        t3 = yes (
          builtins.elem "/home/ana/.local/share" (
            map (d: d.directory) c.environment.persistence."/persist".directories
          )
        );
        t4 = no (
          (builtins.elem "/home/ana/.local/share" (
            map (d: d.directory) nas.environment.persistence."/persist".directories
          ))
        );
      };
      facter = {
        t1 = yes (nas.facter.reportPath != null);
        t2 = no ((c ? facter));
      };
      builders = {
        t1 = yes (c.nix.distributedBuilds);
        t2 = eq (map (m: m.hostName) c.nix.buildMachines) ([ "10.0.0.1" ]);
      };
    };
}
