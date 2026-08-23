# conform-nvim is a formatter
{
  plugins.conform-nvim = {
    enable = true;
    autoLoad = true;
    settings.formatters_by_ft = {
      fennel = [ "fnlfmt" ];
      clojure = [ "cljfmt" ];
      haskell = [ "ormolu" ];
      javascript = [ "prettierd" ];
      javascriptreact = [ "prettierd" ];
      typescript = [ "prettierd" ];
      typescriptreact = [ "prettierd" ];
      python = [ "black" ];
      lua = [ "stylua" ];
      markdown = [ "prettierd" ];
      nix = [ "nixfmt" ];
      html = [ "rustywind" "stylelint" ];
      css = [ "stylelint" ];
      bash = [ "beautysh" ];
      cabal = [ "cabal_fmt" ];
      json = [ "fixjson" ];
      yaml = [ "yamlfmt" ];
      ocaml = [ "ocamlformat" ];
    };
  };

  __depPackages.nixfmt.default = "nixfmt";
  dependencies.nixfmt.enable = true;

}
