inputs@{
  pkgs,
  localPkgs,
  pkgsLib,
  localLib,
  ...
}:

let
  devShell = (import ./headless.nix inputs).passthru.tmuxless.overrideAttrs (old: {
    name = "sieyesShell";

    buildInputs =
      old.buildInputs
      ++ (with pkgs; [
        kdePackages.okular # ebook/pdf/djvu/etc. reader
        bottles # games launcher
        google-chrome
        qimgv # image viewer
        vlc
        bitwarden-cli

        #testing these for a workflow for querying the psql server
        visidata
        harlequin
      ])
      ++ (with localPkgs; [
        firefox
        kitty # terminal emulator
      ]);

  });
in
localLib.tmuxifyDevShell {
  inherit localPkgs devShell;
  name = "sieyesShell-tmuxed";
  shell = localPkgs.nushell;
}
