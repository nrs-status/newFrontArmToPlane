{
  pkgs,
  localPkgs,
  pkgsLib,
  ...
}:

let
  headless = import ./headless.nix {
    inherit pkgs localPkgs pkgsLib;
  };
in
headless.overrideAttrs (old: {
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
      kitty #terminal emulator
    ]);

  shellHook = ''
    export THATWATERCHARMANDER_PATH=/home/sieyes/baghdadPlane/flakes/newThatWaterCharmander/ #required for script that updates twc's fatp input
    export FRONTARMTOPLANE_PATH=/home/sieyes/baghdadPlane/flakes/newFrontArmToPlane/
    exec ${pkgsLib.getExe localPkgs.nushell}
  '';
})
