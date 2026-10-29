# web-1 and web-2 come from JSON: their names become refs.
{ yen, lib, ... }:
{
  yen.host = lib.mapAttrs (
    _: h:
    h
    // {
      environment = yen.environment.${h.environment};
      channel = yen.channel.${h.channel};
      system = yen.system.${h.system};
    }
  ) (lib.importJSON ./_inventory.json);
}
