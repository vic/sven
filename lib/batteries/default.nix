# Batteries: values for keys you write. A battery names no kind, sink, aspect or field: it reads `scope` and `sinks`,
# and takes a sink it reads as a ref. A domain's batteries live under its name.
{
  nixos = import ./nixos.nix;
}
