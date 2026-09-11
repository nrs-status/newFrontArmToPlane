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
      jc # convert command output to structured json 
      grex # generate regex from test cases
      rgx # explain what a regex pattern does
      tldr # community cheatsheet for commands
      navi # personal commandline cheatsheet manager
      nix-index # provides nix-locate, which can find which package provides a given command
      worktrunk # wrapper for git worktrees
      bubblewrap # unpriviledged containerization tool
      delta # git diff pretty printer
      moreutils # because it contains `vipe`, which allows piping in and out of $EDITOR 
      atuin # terminal history manager
      jless # interactive json navigator

      gum #testing it out to make quick TUIs
      tree-sitter #testing out whether I can use it to extract substrings
      pet # testing out, snippet manager

      #testing these for a workflow for querying the psql server
      visidata
      harlequin
      pgcli #complementary to `psql`. `pgcli` is for interactive use, `psql` for scripting
    ]
    ++ (with localPkgs; [
      montezumaCirclesScroll.full # nixvim `full` profile
      firefox
      pi #coding harness
      fish #shell
      nushell #testing out fish alternative
      tmux #terminal multiplexer
      sesh #tmux session manager
      kitty #terminal emulator
      scripts.update-twc-fatp-input
      scripts.compare-flake-pins 
      scripts.llm-gcm
      pi-vm.run-pi-vm
      weechat #irc and matrix client
      git #overrides wranHeart's `git`
      tell # note-making client for the `doc` db (internalized from the former `tell' flake)
      pi-json-span-processor # aggregates `pi --mode json' event streams into spans
      broot # dir navigator

      television #testing it out, alternative to fzf
    ]);

  shellHook = ''
    export THATWATERCHARMANDER_PATH=$(cat /run/secrets/paths/wranHearst/thatWaterCharmander) #required for script that updates twc's fatp input
    export FRONTARMTOPLANE_PATH=$(cat /run/secrets/paths/wranHearst/frontArmToPlane)
    exec ${pkgsLib.getExe localPkgs.nushell}
    echo "sieyes shell loaded"
  '';
}
