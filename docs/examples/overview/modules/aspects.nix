# Aspects: behavior, active where `at` holds. Each key gives one element to the sink of that name.
{ yen, ... }:
{
  yen.aspects.basics = {
    at = yen.kinds.machine; # every machine
    packages = "git";
  };
  yen.aspects.design = {
    at = yen.machine.studio; # one machine
    packages = "gimp";
  };
  yen.aspects.versioned-assets = {
    at = yen.aspects.design; # wherever `design` is active
    packages = "git"; # `set` keeps one copy
  };
}
