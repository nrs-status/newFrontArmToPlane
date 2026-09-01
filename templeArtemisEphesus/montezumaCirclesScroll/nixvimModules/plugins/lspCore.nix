{
  plugins.lsp = {
    enable = true;
    servers = {

      nixd = {
        enable = true;
        settings = {
          # Let nixd evaluate nixpkgs so its LSP can resolve lib functions and
          # report their signature/documentation on hover (K), in completions,
          # and via signature help while typing function arguments.
          nixpkgs = {
            expr = "import <nixpkgs> { }";
          };
          # it seems to me this setting is taken care of by `conform`; enable it if not
          # formatting = {
          #   command = [ "nixfmt" ];
          # };
        };
      };

      bashls.enable = true;

      taplo = {
        enable = true;
      };

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
