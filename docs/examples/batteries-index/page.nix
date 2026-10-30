{
  title = "Battery packs";
  description = "Ready rules for common jobs, in yen.lib.batteries. You write every key; a battery is the value. Or write your own.";
  section = "batteries";
  order = 0;
  route = "batteries";

  body =
    { docs, pages, ... }:
    [
      ''
        The yen engine is domain independent: it knows no host, no user and no NixOS. The examples in these docs write
        every rule by hand, so you can see each step.

        Many rules come back in every fleet. `yen.lib.batteries` has them ready, as plain Nix values:

        - Generic batteries, at the top of `yen.lib.batteries`, know no domain: `mesh`, `claim`, `ordered`.
        - A pack is the batteries of one domain, under its name: `yen.lib.batteries.nixos`.

        A battery never adds a word to your fleet. You write `yen.kinds.…`, the sinks and the aspects with your own
        names. The battery is the value of one key. It reads only `scope` and `sinks`, and it takes the sinks it reads
        as refs, so it works in any fleet:
      ''
      (docs.nix ''
        yen.kinds.host.sinks.unfree.nixos = yen.lib.batteries.nixos.unfree { from = yen.kinds.host.sinks.unfree; };
        yen.aspects.hostname = { at = yen.kinds.host; nixos = yen.lib.batteries.nixos.hostname; };
      '')
      ''
        When a battery does not fit, write your own with the same shape. It is a few lines of Nix in your fleet.
      ''
      (docs.links (
        map (p: {
          title = p.title;
          href = "/${p.route}/";
          inherit (p) description;
        }) (builtins.filter (p: p.section == "batteries" && p.route != "batteries") pages)
      ))
    ];
}
