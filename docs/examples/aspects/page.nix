{
  title = "Aspects";
  description = "Behavior at scopes. An aspect is active where `at` holds, and gives elements to sinks by key.";
  section = "concepts";
  order = 6;

  body =
    { docs, result, ... }:
    [
      ''
        An aspect is one feature. It is active at every scope where its `at` predicate holds.
        Each other key gives one element to the sink of that name. The element is a value, or a function
        that asks for args (see [Args](/concepts/args/)).

        In this example, hosts collect `packages`. Users live under hosts and have no `packages` sink,
        so the packages of a user go up to its host.
      ''
      (docs.file "modules/fleet.nix")
      ''
        ## One aspect, many files

        `at` from several files is a union. The keys of every file apply wherever the aspect is active:
      ''
      (docs.tabs [
        {
          label = "nginx/web.nix";
          body = docs.file "modules/nginx/web.nix";
        }
        {
          label = "nginx/db.nix";
          body = docs.file "modules/nginx/db.nix";
        }
      ])
      ''
        `nginx` is active at both hosts, never at the users. Read it with `result.active.nginx`:
      ''
      (docs.value result.active.nginx)
      ''
        ## Static content lands once

        Static content counts once per receiver. `zsh` is active at `web` and at its two users, and `web` gets one `zsh`.
        Content that names the scope (`{ user, ... }:`) lands once per scope: each user gives its own dotfiles.
      ''
      (docs.file "modules/shells.nix")
      (docs.value result.flake.packages)
      (docs.caution "Aspects do not flow down" ''
        An aspect is active only where `at` holds. It never reaches the children of that scope:
        a host profile does not reach the users or guests of the host. Elements go up, never down.
      '')
      (docs.tip "Static or function?" ''
        Use a static value for data that all receivers share. Use a function value for data that each scope owns.
      '')
    ];

  checks =
    { result, ... }:
    {
      union =
        result.active.nginx."fleet:main/host:web"
        && result.active.nginx."fleet:main/host:db"
        && !result.active.nginx."fleet:main/host:web/user:bob";
      zsh-once = builtins.length (builtins.filter (p: p == "zsh") result.flake.packages.web) == 1;
      dotfiles =
        builtins.elem "dotfiles-alice" result.flake.packages.web
        && builtins.elem "dotfiles-bob" result.flake.packages.db;
    };
}
