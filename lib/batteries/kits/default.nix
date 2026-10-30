# kits and assemblies: a kit is data (roles, typed interface, constraints, exports); an assembly is one use of a kit,
# its `kit` a ref and each role's machines an `at` predicate. Members per (assembly, role), exports, contract.
{
  members = import ./members.nix;
  exports = import ./exports.nix;
  contract = import ./contract.nix;
  settings-typed = import ./settings-typed.nix;
}
