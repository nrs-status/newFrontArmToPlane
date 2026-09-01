{ pkgs, localPkgs, pkgsLib, ... }:

pkgs.mkShell {
  name = "sieyesShell";

  buildInputs =
    with pkgs;
    [
      zoxide # 'cd' command alternative
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
      fzf # fuzzy searcher
      television # fzf alternative, picker
      grex # generate regex from test cases
      rgx # explain what a regex pattern does
      tldr # community cheatsheet for commands
      navi # personal commandline cheatsheet manager
      sesh # terminal session manager
      nix-index # provides nix-locate, which can find which package provides a given command
      worktrunk # wrapper for git worktrees
      tmux #terminal multiplexer
      sesh #tmux session manager
    ]
    ++ (with localPkgs; [
      montezumaCirclesScroll.full # nixvim `full` profile
      firefox
      pi
      fish
    ]);

  shellHook = ''
    exec ${pkgsLib.getExe localPkgs.scripts.fishWConfig}
    echo "sieyes shell loaded"
  '';
}
