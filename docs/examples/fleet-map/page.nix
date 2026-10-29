{
  title = "The reference fleet";
  description = "Every module of templates/fleet, the running specification of yen, with what it shows.";
  section = "reference";
  order = 4;

  body =
    { docs, inputs, ... }:
    let
      root = inputs.yen + "/templates/fleet/modules";
      repo = "https://github.com/vic/yen/blob/main/templates/fleet/modules";
      # the first comment line of a file: what it shows
      about =
        f:
        let
          l = builtins.head (builtins.filter builtins.isString (builtins.split "\n" (builtins.readFile f)));
          m = builtins.match "# (.*)" l;
        in
        if m == null then "" else builtins.head m;
      nixIn =
        d:
        builtins.filter (n: builtins.match "[^_].*\\.nix" n != null) (
          builtins.attrNames (builtins.readDir d)
        );
      dirs = builtins.filter (d: (builtins.readDir root).${d} == "directory") (
        builtins.attrNames (builtins.readDir root)
      );
      row = d: n: [
        "[`${d}/${n}`](${repo}/${d}/${n})"
        (builtins.replaceStrings [ "|" ] [ "\\|" ] (about (root + "/${d}/${n}")))
      ];
    in
    [
      ''
        [`templates/fleet`](https://github.com/vic/yen/tree/main/templates/fleet) is a complete running specification of yen.
        It models every capability of Den, den-hoag and clan, and the advanced cases of several real fleets. Each pattern has a check.
        It is big on purpose: read these docs first, then use the fleet to look up how a pattern looks at scale.

        This index is read from the fleet's files: each row is a module and its first comment line.
      ''
      (docs.sh ''
        git clone https://github.com/vic/yen && cd yen/templates/fleet
        nix eval --impure --file tests.nix failed   # [ ]: a check for each pattern
      '')
    ]
    ++ map (
      d: "## ${d}\n\n" + docs.table [ "Module" "What it shows" ] (map (row d) (nixIn (root + "/${d}")))
    ) dirs;

  checks =
    { inputs, ... }:
    {
      has-modules = builtins.pathExists (inputs.yen + "/templates/fleet/modules/topology/fleet.nix");
    };
}
