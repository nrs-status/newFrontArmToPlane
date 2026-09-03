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
      nix-index # provides nix-locate, which can find which package provides a given command
      worktrunk # wrapper for git worktrees
      fd # `find` replacement
      trash-cli # safer `rm`
      bubblewrap # unpriviledged escalation tool
    ]
    ++ (with localPkgs; [
      montezumaCirclesScroll.full # nixvim `full` profile
      firefox
      pi #coding harness
      fish #shell
      tmux #terminal multiplexer
      sesh #tmux session manager
    ]);

  shellHook = ''
    THATWATERCHARMANDER_PATH=$(cat /run/secrets/THATWATERCHARMANDER_PATH) #required for script that updates twc's fatp input
    exec ${pkgsLib.getExe localPkgs.fish}
    echo "sieyes shell loaded"
  '';
}
