{ yen, ... }:
{
  # `inputs.yen.lib.mkFlake` expects this function to exist.
  # Here we ask for a **greetings** sink that will be used
  # for teaching purposes, as the output of our flake.
  yen.flake = { greetings, ... }: greetings;

  # In this flake we model translations of diffent human languages
  yen.kinds.language.fields.hello = yen.lib.is builtins.isString;

  # World is the container of all our human languages
  yen.kinds.world = {
    spawns.language = world: yen.language;
    # all greetings contributions get merged as attrsets
    sinks.greetings.reduce = yen.lib.reduce.merge;
  };

  # An aspect is configuration behaviour
  yen.aspects.hello = {
    # This predicate indicates where is `hello` active.
    # this can be a kind a particular instance of a kind or any predicate.
    at = yen.kinds.language;

    # This aspect contributes an element to the `greetings` sink.
    # Since `hello` is active for each language, it produces two entries.
    greetings =
      { language, ... }:
      {
        ${language.name} = language.hello;
      };
  };

  # define an instance of our world kind
  yen.world.earth = { };
  # and two languages with their respective field set.
  yen.language.en.hello = "Hello";
  yen.language.es.hello = "Hola";
}
