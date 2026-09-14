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

      #testing these for a workflow for querying the psql server
      visidata
      harlequin
    ])
    ++ (with localPkgs; [
      firefox
      kitty #terminal emulator
    ]);

  shellHook = ''
    export THATWATERCHARMANDER_PATH=$(cat /run/secrets/paths/wranHearst/thatWaterCharmander) #required for script that updates twc's fatp input
    export FRONTARMTOPLANE_PATH=$(cat /run/secrets/paths/wranHearst/frontArmToPlane)
    exec ${pkgsLib.getExe localPkgs.nushell}
  '';
})
