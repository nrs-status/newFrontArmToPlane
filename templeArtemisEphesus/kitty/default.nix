{ pkgs, localLib, ... }:
let
  kittyConf = pkgs.writeText "kitty-conf" (import ./conf.nix {
    gruvboxDarkConfig = "${pkgs.kitty-themes}/share/kitty-themes/themes/gruvbox-dark.conf";
    inherit pkgs;
  });

  # kitty resolves `font_family`/`symbol_map` families through fontconfig, and
  # fontconfig only searches directories listed in its configuration — placing
  # font packages on `PATH` (the previous `runtimeInputs` approach) does
  # nothing, so kitty silently fell back to DejaVu Sans.
  #
  # Instead we generate a fontconfig file that keeps the system configuration
  # (so every font and rendering rule already installed keeps working) and
  # additionally registers the directories of the fonts this wrapper packages:
  #
  # - Iosevka: the terminal font (`font_family` etc. in conf.nix)
  # - nerd-fonts.iosevka: not referenced by conf.nix, but ships the same Nerd
  #   Font glyph repertoire and can serve as a manual fallback
  # - nerd-fonts.symbols-only: the "Symbols Nerd Font Mono" family used by the
  #   `symbol_map` line in conf.nix for icons/powerline glyphs
  fontDirectories = [
    "${pkgs.iosevka}/share/fonts/truetype"
    "${pkgs.nerd-fonts.iosevka}/share/fonts/truetype"
    "${pkgs.nerd-fonts.symbols-only}/share/fonts/truetype"
  ];
  fontConfigFile = pkgs.writeText "kitty-fontconfig.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <!-- keep the system font configuration (fonts + rendering rules);
           ignore_missing lets this work in sandboxes without /etc/fonts -->
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      ${pkgs.lib.concatMapStringsSep "\n" (dir: "<dir>${dir}</dir>") fontDirectories}
    </fontconfig>
  '';
in
pkgs.lib.makeOverridable
  (
    { optsAfterArgs ? true }:
    localLib.mkWrapperScript {
      name = "kitty";
      pkgToWrap = pkgs.kitty;
      # the font packages are kept in the closure via their directory
      # references in `fontConfigFile` above; they must not be (only) on PATH
      runtimeInputs = [ ];
      envVars = [
        {
          key = "FONTCONFIG_FILE";
          value = "${fontConfigFile}";
        }
      ];
      opts = [
        {
          dash = "--";
          optName = "config";
          val = "${kittyConf}";
        }
      ];
      # kitty only recognizes its `+command` mode (e.g. `+runpy`) when it is the
      # first CLI argument, so by default options are appended after "$@" instead
      # of prepended. Otherwise `kitty +runpy ...` silently launches a GUI instead.
      #
      # Note the trade-off: appending also means that any positional argument
      # (e.g. `kitty bash`) receives the trailing `--config <conf>` as *its own*
      # argument, since kitty's parser stops at the first positional and passes
      # the rest to the child program. Callers that launch programs this way can
      # override the wrapper with `.override { optsAfterArgs = false; }`, which
      # prepends the options so they reach kitty itself.
      inherit optsAfterArgs;
    }
  )
  { }
