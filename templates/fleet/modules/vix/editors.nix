# vix: a child kind declared in another file. Each system gets editor profiles; `features` gate aspects;
# the `vim` sink builds one package per profile.
{
  yen,
  lib,
  inputs,
  ...
}:
let
  inherit (yen.helpers) listOf enum;
  features = [
    "lsp"
    "git"
    "theme"
  ];
  has =
    f:
    yen.lib.all [
      yen.kinds.vim
      (s: lib.elem f s.features)
    ]; # a predicate runs at every scope: test the kind first
in
{
  yen.kinds.system.spawns.vim = s: lib.optionalAttrs (s.name == "x86_64-linux") yen.vim;
  yen.kinds.vim = {
    fields = {
      features = yen.lib.opt (listOf (enum features)) [ ];
      theme = yen.lib.maybe lib.types.str;
    };
    sinks.vimrc = {
      # not `vim`: a sink named like its kind loses the `vim` arg to the kind (design §15 SQ18)
      reduce = yen.lib.reduce.set;
      out =
        {
          system,
          vimrc,
          scope,
          ...
        }:
        {
          packages.${system.name}."vim-${scope.name}" =
            inputs.nixpkgs.legacyPackages.${system.name}.writeText "vim-${scope.name}.lua"
              (lib.concatLines vimrc);
        };
    };
  };
  yen.vim.dev = {
    features = [
      "lsp"
      "git"
    ];
    theme = "tokyonight";
  };
  yen.vim.min = { };
  yen.aspects.vim-lsp = {
    at = has "lsp";
    vimrc = "vim.lsp.enable('nixd')";
  };
  yen.aspects.vim-git = {
    at = has "git";
    vimrc = "require('gitsigns').setup()";
  };
  yen.aspects.vim-theme = {
    at = yen.lib.all [
      yen.kinds.vim
      (s: s.theme != null)
    ];
    vimrc = { vim, ... }: "vim.cmd.colorscheme('${vim.theme}')";
  };
  yen.aspects.vim-base = {
    at = yen.kinds.vim;
    vimrc = "vim.o.number = true";
  };
}
