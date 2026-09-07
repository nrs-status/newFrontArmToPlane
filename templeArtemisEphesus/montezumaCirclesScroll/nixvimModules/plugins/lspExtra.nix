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

    nushell = { 
      enable = true; 
      # todo: refactor mkNixvim so that I can call pass localPkgs to modules. it would probably be a good idea, at the same time, to stop punning package names (but punning binaries is fine, proper nix expressions shouldn't call packages by path basename)
      # package = localPkgs.nushell;
    };


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
