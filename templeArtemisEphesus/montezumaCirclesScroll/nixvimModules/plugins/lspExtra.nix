{
  plugins.lsp.servers = {

      arduino_language_server = { enable = true; };

      clangd = { enable = true; };

      clojure_lsp = { enable = true; };

      neocmake = { enable = true; };

      dockerls = { enable = true; };

      fennel_ls = { enable = true; };

      fish_lsp = { enable = true; };

      fstar = { enable = true; };

      gopls = { enable = true; };

      html = { enable = true; };

      idris2_lsp = { enable = true; };

      java_language_server = { enable = true; };

      koka = { enable = true; };

      kotlin_language_server = { enable = true; };


      postgres_lsp = { enable = true; };

    rust_analyzer = {
      enable = true; 
      installCargo = false; 
      installRustc = false;
    };

      scheme_langserver = { enable = true; };

      sqls = { enable = true; };

      vsrocq = { enable = true; };

      jsonls = { enable = true; };

      yamlls = { enable = true; };



  };
}
