{
  title = "NixOS patterns";
  description = "What NixOS users write by hand in every multi-host flake, and the yen form. Each page is a tested template.";
  section = "nixos";
  order = 0;
  route = "nixos";

  body =
    { docs, pages, ... }:
    [
      ''
        These pages start from patterns that NixOS users ask about on [NixOS Discourse](https://discourse.nixos.org):
        a `mkHost` function, `specialArgs`, home-manager inside and outside NixOS, `allowUnfreePredicate`, and
        configuration that depends on the other hosts. Each page shows the usual code and the yen form, and its checks
        evaluate the real NixOS and home-manager configurations.
      ''
      (docs.links (
        map (p: {
          title = p.title;
          href = "/${p.route}/";
          inherit (p) description;
        }) (builtins.filter (p: p.section == "nixos" && p.route != "nixos") pages)
      ))
    ];
}
