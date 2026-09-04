{ pkgs, localPkgs, pkgsLib, ... }:

pkgs.mkShell {
  name = "sieyesShell";

  buildInputs =
    with pkgs;
    [
      zoxide # 'cd' command alternative
      kdePackages.okular # ebook/pdf/djvu/etc. reader
      bottles # games launcher
      google-chrome
      wofi # launcher/menu
      btop # system monitor
      qimgv # image viewer
      vlc
      television # fzf alternative, picker
      grex # generate regex from test cases
      rgx # explain what a regex pattern does
      tldr # community cheatsheet for commands
      navi # personal commandline cheatsheet manager
      nix-index # provides nix-locate, which can find which package provides a given command
      worktrunk # wrapper for git worktrees
      bubblewrap # unpriviledged escalation tool
      delta # git diff pretty printer
    ]
    ++ (with localPkgs; [
      montezumaCirclesScroll.full # nixvim `full` profile
      firefox
      pi #coding harness
      fish #shell
      tmux #terminal multiplexer
      sesh #tmux session manager
      kitty #terminal emulator
      scripts.update-twc-fatp-input
      weechat #irc and matrix client
      git #overrides wranHeart's `git`
    ]);

  shellHook = ''
    export THATWATERCHARMANDER_PATH=$(cat /run/secrets/THATWATERCHARMANDER_PATH) #required for script that updates twc's fatp input
    exec ${pkgsLib.getExe localPkgs.fish}
    echo "sieyes shell loaded"
  '';
}
