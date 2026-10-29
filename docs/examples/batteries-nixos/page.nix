{
  title = "NixOS batteries";
  description = "yen.lib.batteries.nixos: system, hostname, define-user, primary-user, unfree, insecure. NixOS options are the domain; yen keys are yours.";
  section = "batteries";
  route = "batteries/nixos";
  order = 2;

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
      ''
      (docs.file "modules/fleet.nix")
      (docs.file "modules/aspects.nix")
      (docs.file "modules/machines.nix")
      ''
        Each battery is a few lines. The pages [Every Den battery](/den/batteries/) and
        [Unfree packages from many files](/nixos/unfree/) write the same rules by hand. When a battery does not fit your
        fleet, copy those lines and change them: see [Write your own](/batteries/generic/#write-your-own).
      ''
    ];

  checks =
    { result, ... }:
    {
      hosts = builtins.attrNames result.flake.nixosConfigurations == [ "desk" ];
    };

  e2e =
    { flake, ... }:
    let
      c = flake.nixosConfigurations.desk.config;
      ok = p: (builtins.tryEval flake.nixosConfigurations.desk.pkgs.${p}.drvPath).success;
    in
    {
      hostname = c.networking.hostName == "desk";
      accounts = c.users.users.ana.isNormalUser && c.users.users.bob.home == "/home/bob";
      admin =
        builtins.elem "wheel" c.users.users.ana.extraGroups
        && !(builtins.elem "wheel" c.users.users.bob.extraGroups);
      unfree = ok "steam-unwrapped" && ok "vscode" && !(ok "zoom-us");
      insecure = c.nixpkgs.config.permittedInsecurePackages == [ "olm-3.2.16" ];
    };
}
