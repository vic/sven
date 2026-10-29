{
  title = "Users and homes";
  description = "home-manager inside NixOS and as a standalone home, from one aspect.";
  section = "recipes";
  order = 1;

  body =
    { docs, r, ... }:
    [
      ''
        A person uses several machines. Some run NixOS, some only home-manager. In yen the person is data,
        and their home is one aspect that is active in both places.
      ''
      (docs.fileWith "{17-20,22-28}" "modules/fleet.nix")
      ''
        - A `user` lives under each host in its `hosts`. Its `homeManager` sink forwards into the host's NixOS.
        - A `home` lives under the fleet. Its `homeManager` sink builds `homeConfigurations.<name>`.
      ''
      (docs.fileWith "{6}" "modules/alice.nix")
      (docs.file "modules/machines.nix")
      ''
        `alice-home` is active at alice's user scope and at her home:
      ''
      (docs.value r.active.alice-home)
      (docs.scopes r)
      (docs.sh ''
        sudo nixos-rebuild switch --flake .#server
        home-manager switch --flake '.#alice@laptop'
      '')
      (docs.tip "A home that reads its host" ''
        A home can also live under a host: give `host` a `spawns.home`. The home then reads the host's sinks like any child,
        and still builds its own `homeConfigurations`. A home's sink with no keys keeps its content away from the host.
        See [Routing and walls](/concepts/routing/#walls).
      '')
    ];

  checks =
    { r, ... }:
    {
      both =
        r.active.alice-home."fleet:main/home:alice@laptop"
        && r.active.alice-home."fleet:main/host:server/user:alice";
    };
  e2e =
    { flake, ... }:
    {
      nixos-home =
        flake.nixosConfigurations.server.config.home-manager.users.alice.programs.git.userName == "Alice";
      standalone = flake.homeConfigurations."alice@laptop".config.programs.git.userName == "Alice";
      standalone-builds = flake.homeConfigurations."alice@laptop".activationPackage ? drvPath;
    };
}
