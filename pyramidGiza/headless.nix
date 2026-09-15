{ pkgs, localPkgs, pkgsLib, ... }:

pkgs.mkShell {
  name = "headless";

  buildInputs =
    with pkgs;
    [
      zoxide # 'cd' command alternative
      wofi # launcher/menu
      btop # system monitor
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

      pgcli #complementary to `psql`. `pgcli` is for interactive use, `psql` for scripting
    ]
    ++ (with localPkgs; [
      montezumaCirclesScroll.full # nixvim `full` profile
      pi #coding harness
      nushell
      tmux #terminal multiplexer
      sesh #tmux session manager
      scripts.update-twc-fatp-input
      scripts.compare-flake-pins
      scripts.llm-gcm
      pi-vm.run-pi-vm
      pi-vm.run-pi-microvm
      weechat #irc and matrix client
      git #overrides wranHeart's `git`
      tell # note-making client for the `doc` db (internalized from the former `tell' flake)
      arunman # run manager for pi microvm jobs (internalized from `run-manager.2')
      pi-json-span-processor # aggregates `pi --mode json' event streams into spans
      broot # dir navigator
      television #testing it out, alternative to fzf
    ]);

  shellHook = ''
    exec ${pkgsLib.getExe localPkgs.nushell}
  '';
}
