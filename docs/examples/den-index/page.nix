{
  title = "Den patterns";
  description = "Den batteries, includes, provides, classes and the dendritic aspect patterns, in yen. Each page is a tested template.";
  section = "den";
  order = 0;
  route = "den";

  body =
    { docs, pages, ... }:
    [
      ''
        These pages start from how people write Den today. We read the 20 most starred public Den configurations on
        GitHub, counted which batteries and keys they use, and wrote one page per common shape. Each page shows the
        Den code and the yen form, and its checks evaluate the real NixOS and home-manager configurations.

        Start with [From Den](/migrate/from-den/) for the default template, hosts, users and quirks. The
        [reference fleet](https://github.com/vic/yen/tree/main/templates/fleet) shows every capability that Den's CI tests.
      ''
      (docs.links (
        map (p: {
          title = p.title;
          href = "/${p.route}/";
          inherit (p) description;
        }) (builtins.filter (p: p.section == "den" && p.route != "den") pages)
      ))
    ];
}
