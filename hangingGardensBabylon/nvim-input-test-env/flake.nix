{
  description = "nvim-input-test-env: tap user keystrokes and Neovim-registered keys";

  # The parent flake already pins and builds the whole nixvim configuration
  # (including the `full` profile in
  # ./templeArtemisEphesus/montezumaCirclesScroll).  Reusing it as an input
  # means this environment loads *exactly* the same `full` package that the
  # rest of the repository uses, instead of a copy that can drift.
  #
  # NOTE: this has to be an absolute path.  Nix copies a local flake into the
  # store and resolves relative `path:` inputs against that copy, where
  # `../..` no longer points at the repository root.  Change this one line if
  # the checkout moves.
  inputs.root.url = "path:/home/sieyes/baghdadPlane/flakes/newFrontArmToPlane.nvim-input-test-env";

  outputs =
    { self, root }:
    let
      args = root.localPkgsArgs;
      pkgs = args.pkgs;

      # The `full` nixvim profile built from
      # templeArtemisEphesus/montezumaCirclesScroll.
      fullNvim = root.packages."x86_64-linux".montezumaCirclesScroll.full;

      keyLog = ./nvim-key-log.lua;
      inputTap = ./input-tap.py;

      defaultLog = "/tmp/nvim-input-test-env/nvim-input.log";

      nvim-input-test = pkgs.writeShellApplication {
        name = "nvim-input-test";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.python3
        ];
        text = ''
          NVIM_INPUT_LOG="''${NVIM_INPUT_LOG:-${defaultLog}}"
          export NVIM_INPUT_LOG
          mkdir -p "$(dirname "$NVIM_INPUT_LOG")"

          # Run the nixvim `full` profile underneath the pty tap.  The tap
          # logs every byte the user sends; the --cmd below installs the
          # vim.on_key listener *before* nixvim sources VIMINIT/init.lua so
          # that it also logs the keypresses Neovim actually registers.
          exec python3 ${inputTap} --log "$NVIM_INPUT_LOG" -- \
            ${fullNvim}/bin/nvim \
            --cmd "lua dofile([[${keyLog}]])" \
            "$@"
        '';
      };
    in
    {
      packages."x86_64-linux" = {
        default = nvim-input-test;
        inherit nvim-input-test;
      };

      apps."x86_64-linux".default = {
        type = "app";
        program = "${nvim-input-test}/bin/nvim-input-test";
      };

      devShells."x86_64-linux".default = pkgs.mkShell {
        packages = [
          nvim-input-test
          pkgs.coreutils
          pkgs.tmux
        ];
        shellHook = ''
          echo "nvim-input-test-env"
          echo "  launch : nvim-input-test [file ...]"
          echo "  log    : ''${NVIM_INPUT_LOG:-${defaultLog}}"
          echo "  follow : tail -f ''${NVIM_INPUT_LOG:-${defaultLog}}"
        '';
      };
    };
}
