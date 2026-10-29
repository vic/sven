# ordered: README sections from any file, each with before and after. The battery finds one order.
{ yen, ... }:
{
  yen.kinds.fleet.sinks.readme = {
    reduce = yen.lib.batteries.ordered;
    out =
      { sinks, ... }:
      {
        readme = builtins.concatStringsSep "\n" sinks.readme;
      };
  };
  yen.aspects.readme-intro = {
    at = yen.kinds.fleet;
    readme = {
      name = "intro";
      value = "# My fleet";
    };
  };
  yen.aspects.readme-hosts = {
    at = yen.kinds.fleet;
    readme = {
      name = "hosts";
      after = [ "intro" ];
      value = "## Hosts";
    };
  };
  # written later, in another file: it goes between the two
  yen.aspects.readme-usage = {
    at = yen.kinds.fleet;
    readme = {
      name = "usage";
      after = [ "intro" ];
      before = [ "hosts" ];
      value = "## Usage";
    };
  };
}
