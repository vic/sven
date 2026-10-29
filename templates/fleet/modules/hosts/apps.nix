# Four app hosts to compare shared pkgs: app-1..3 reuse one pkgs (app-1 leads), app-4 builds its own.
{ yen, lib, ... }:
{
  yen.host = lib.genAttrs [ "app-1" "app-2" "app-3" "app-4" ] (n: {
    environment = yen.environment.lab;
    channel = yen.channel.stable;
    system = yen.system.x86_64-linux;
    addr = "10.0.9.${lib.removePrefix "app-" n}";
    sharedPkgs = n != "app-4";
    trimmedModules = n == "app-2";
  });
}
