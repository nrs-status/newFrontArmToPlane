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
in
pkgs.firefox.override {
  extraPrefsFiles = [ "${./bookmark-remap.js}" ]; #remap Ctrl+D to Ctrl+B
  extraPolicies = {
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

    };
  };
}

#Fable managed to figure out how to do this and provided tests showing that removing the specified extension will adequately produce a firefox without that extension. However: if another firefox process is running while there is a change in declared extensions, the result won't appear until all old sessions are terminated. TODO: figure out if it is possible to bundle a way to check that no old sessions are running
