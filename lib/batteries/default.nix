# Batteries: values for keys you write. A battery names no kind, sink, aspect or field: it reads `scope` and `sinks`,
# takes a sink it reads as a ref, or is a reduce strategy. One file per battery; a domain's batteries are a directory.
# Builtins only.
{
  # generic
  mesh = import ./mesh.nix;
  claim = import ./claim.nix;
  ordered = import ./ordered.nix;
  eval-modules = import ./eval-modules.nix;
  # domains
  nixos = import ./nixos;
  files = import ./files;
  mermaid = import ./mermaid;
  github = import ./github;
  docs = import ./docs;
  devshell = import ./devshell;
}
