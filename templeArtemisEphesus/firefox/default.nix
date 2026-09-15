{ pkgs, ... }:
let
  ublock-origin = pkgs.fetchurl {
    url = "https://addons.mozilla.org/firefox/downloads/file/4940584/ublock_origin-1.73.0.xpi";
    hash = "sha256:0skqcj7y7wm9iycinf7jkyvkhwpbzmxjrmhzdspz82hmffkm3k5w";
  };
  vimium = pkgs.fetchurl {
    url = "https://addons.mozilla.org/firefox/downloads/file/4717567/vimium_ff-2.4.2.xpi";
    hash = "sha256:15nixab67dxah8kzqhdl8yn9yh31kqaq35xib89fjyhfb1kjl7hk";
  };
  bitwarden = pkgs.fetchurl {
    url = "https://addons.mozilla.org/firefox/downloads/file/4970633/bitwarden_password_manager-2026.8.0.xpi";
    hash = "sha256:989ee33f19329af1fc155dcebb7f90a517a7259cea4bfbdd660923d25a7d465a";
  };
in
pkgs.firefox.override {
  extraPrefsFiles = [ "${./bookmark-remap.js}" ]; #remap Ctrl+D to Ctrl+B
  extraPolicies = {
    # Start Firefox in dark mode on every launch. These prefs are what the
    # built-in "Dark" theme sets:
    #   browser.theme.toolbar-theme: 0 = dark toolbars, 1 = light, 2 = follow OS
    #   browser.theme.content-theme: same values, for page content chrome
    #   extensions.activeThemeID: makes the built-in compact dark theme active
    # The "Preferences" policy re-asserts these values at every startup (plain
    # values are set but NOT locked, so the user can still change them during
    # the session).
    Preferences = {
      "browser.theme.toolbar-theme" = 0;
      "browser.theme.content-theme" = 0;
      "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
      # make web content report prefers-color-scheme: dark (0 = dark,
      # 1 = light, 2 = follow browser theme, 3 = follow OS)
      "layout.css.prefers-color-scheme.content-override" = 0;
    };

    ExtensionSettings = {
      # Block (and remove, if present) every extension not explicitly listed.
      "*" = {
        installation_mode = "blocked";
      };
      "uBlock0@raymondhill.net" = {
        installation_mode = "force_installed";
        install_url = "file://${ublock-origin}";
      };
      "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
        installation_mode = "force_installed";
        install_url = "file://${vimium}";
      };
      "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
        installation_mode = "force_installed";
        install_url = "file://${bitwarden}";
      };

    };
  };
}

#Fable managed to figure out how to do this and provided tests showing that removing the specified extension will adequately produce a firefox without that extension. However: if another firefox process is running while there is a change in declared extensions, the result won't appear until all old sessions are terminated. TODO: figure out if it is possible to bundle a way to check that no old sessions are running
