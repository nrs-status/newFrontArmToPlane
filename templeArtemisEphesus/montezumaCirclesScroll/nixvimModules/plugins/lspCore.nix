{
  plugins.lsp = {
    enable = true;
    servers = {

      nixd.enable = true;

      bashls.enable = true;

      lua_ls = {
        enable = true;
        settings.telemetry.enable = false;
        package = null;
      };

      ocamllsp = {
        enable = true;
        package = null;
      };

      hls = {
        enable = true;
        package = null;
        cmd = [ "haskell-language-server" "--lsp" ];
        settings = { plugin = { hlint = { globalOn = true; }; }; };
        installGhc = false;

      };

      ts_ls = { enable = true; };

      pylsp = {
        enable = true;

        settings = {
          plugins = {
            flake8.enabled = true;
            ruff.enabled = true;
          };
        };
      };
    };
  };
}
