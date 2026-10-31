# Batteries: values for keys you write. A battery names no kind, sink, aspect or field: it reads `scope` and `sinks`,
# takes a sink it reads as a ref, or is a reduce strategy. One file per battery; a domain's batteries are a directory.
# Builtins only.
{
  # generic
  mesh = import ./mesh.nix;
  addresses = import ./addresses.nix;
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
  flake-file = import ./flake-file;
  kits = import ./kits;
  vars = import ./vars;
  cachix = import ./cachix;
  secretspec = import ./secretspec;
  exports = import ./exports;
  configurations = import ./configurations.nix;
  darwin = import ./darwin;
  home-manager = import ./home-manager;
  droid = import ./droid;
  microvm = import ./microvm;
  imports = import ./imports.nix;
  deploy = import ./deploy;
  disko = import ./disko;
  install = import ./install;
  secrets = import ./secrets;
  k8s = import ./k8s;
  terranix = import ./terranix;
  editors = import ./editors;
  ai = import ./ai;
  distributed = import ./distributed;
}
