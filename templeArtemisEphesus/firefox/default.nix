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
  gopass-bridge = pkgs.fetchurl {
    url = "https://addons.mozilla.org/firefox/downloads/file/4630675/gopass_bridge-2.1.1.xpi";
    hash = "sha256:e8ac742baf8fd9954672b778440acf9d87666d93df470d8d7be53e2cb051141f";
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
      # gopass Password Manager bridge (https://github.com/gopasspw/gopassbridge)
      "{eec37db0-22ad-4bf1-9068-5ae08df8c7e9}" = {
        installation_mode = "force_installed";
        install_url = "file://${gopass-bridge}";
      };

    };
  };
}

#Fable managed to figure out how to do this and provided tests showing that removing the specified extension will adequately produce a firefox without that extension. However: if another firefox process is running while there is a change in declared extensions, the result won't appear until all old sessions are terminated. TODO: figure out if it is possible to bundle a way to check that no old sessions are running
