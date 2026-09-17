{ pkgs, pkgsLib, ... }:
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

  # The gopass-bridge extension talks to gopass over Firefox's native
  # messaging API: Firefox spawns the `gopass-jsonapi` binary declared in a
  # native messaging manifest. `gopass-jsonapi` in turn spawns `gopass`,
  # which spawns `gpg`, which spawns a pinentry program to ask for the GPG
  # key passphrase. All of those are looked up in PATH inherited from the
  # Firefox process, so we wrap `gopass-jsonapi` with a PATH containing
  # everything the chain needs. Without this, stores backed by
  # passphrase-protected GPG keys cannot be used from Firefox (the tools are
  # missing or pinentry cannot be found).
  gopassJsonapiWrapped = pkgs.runCommand "gopass-jsonapi-wrapped"
    {
      nativeBuildInputs = [ pkgs.makeWrapper ];
    }
    ''
      mkdir -p $out/bin
      makeWrapper ${pkgs.gopass-jsonapi}/bin/gopass-jsonapi $out/bin/gopass-jsonapi \
        --prefix PATH : ${pkgsLib.makeBinPath [
          pkgs.gopass # the password manager itself
          pkgs.gnupg # gpg / gpg-agent: decrypt the password store
          pkgs.git # gopass stores may be git-backed
          pkgs.pinentry-qt # GUI passphrase prompt (X11/Wayland), spawned by gpg-agent from Firefox's environment
          pkgs.pinentry-curses # terminal passphrase prompt fallback
        ]}
    '';

  # Native messaging manifest as Firefox expects it (see
  # https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging).
  # The name/file name must match what gopass-bridge connects to
  # (`com.justwatch.gopass`), the path must point at our wrapped binary, and
  # the extension id must match the gopass-bridge xpi installed above.
  gopassNativeMessagingHost = pkgs.runCommand "gopass-firefox-native-messaging-host" { } ''
    mkdir -p $out/lib/mozilla/native-messaging-hosts
    ${pkgs.jq}/bin/jq -n \
      --arg path "${gopassJsonapiWrapped}/bin/gopass-jsonapi" \
      '{
        name: "com.justwatch.gopass",
        description: "Gopass wrapper to search and return passwords",
        path: $path,
        type: "stdio",
        allowed_extensions: ["{eec37db0-22ad-4bf1-9068-5ae08df8c7e9}"]
      }' \
      > $out/lib/mozilla/native-messaging-hosts/com.justwatch.gopass.json
  '';
in
pkgs.firefox.override {
  nativeMessagingHosts = [ gopassNativeMessagingHost ];
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
