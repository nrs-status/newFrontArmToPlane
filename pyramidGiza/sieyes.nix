{ pkgs, localPkgs, ... }:

pkgs.mkShell {
  name = "sieyesShell";

  buildInputs = with pkgs; [
    fish
    kdePackages.okular # ebook/pdf/djvu/etc. reader
    unzip
    unrar
    bottles # games launcher
    google-chrome
    kitty # terminal emulator
    wofi # launcher/menu
    btop # system monitor
    qimgv # image viewer
    vlc
    pi-coding-agent
  ] ++ (with localPkgs; [
      montezumaCirclesScroll.full #nixvim `full` profile
      firefox
    ]);

  shellHook = ''
    exec fish
    echo "sieyes shell loaded"
  '';
}
