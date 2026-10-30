# clan-like inventories: service instances as data, members per (instance, role), exports, contracts.
{
  members = import ./members.nix;
  exports = import ./exports.nix;
  contract = import ./contract.nix;
  unknown-tags = import ./unknown-tags.nix;
  settings-typed = import ./settings-typed.nix;
  extra-modules = import ./extra-modules.nix;
}
