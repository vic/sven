# the modules of sink `from` and `modules`, evaluated with `lib.evalModules`: any module system (NixOS options,
# flake-parts, sini/files). `result` turns the evaluation into the value, `config` by default.
#   out = eval-modules { from = yen.kinds.repo.sinks.files; inherit lib; modules = [ inputs.files.module ]; };
{
  from,
  lib,
  modules ? [ ],
  specialArgs ? { },
  result ? e: e.config,
}:
{ sinks, ... }:
result (
  lib.evalModules {
    modules = modules ++ sinks.${from.__sink};
    inherit specialArgs;
  }
)
