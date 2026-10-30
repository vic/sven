# vars: generators of secret and public files per machine, the plan of files that reach a machine, reads checks.
{
  generators = import ./generators.nix;
  vars-plan = import ./vars-plan.nix;
  secret-reads = import ./secret-reads.nix;
  public-value = import ./public-value.nix;
}
