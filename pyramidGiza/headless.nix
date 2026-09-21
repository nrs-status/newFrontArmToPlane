{ pkgs, localPkgs, pkgsLib, newPkgs, ... }:

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
      nix-output-monitor # monitor nix builds

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
      weechat #irc and matrix client
      git #overrides wranHeart's `git`
      broot # dir navigator
      television #testing it out, alternative to fzf
      gopass # user password manager
      gnupg # shadows current twc package with one that declares a pinentry program
    ]) ++ ( with newPkgs; [
      pi-vm.run-pi-vm
      pi-vm.run-pi-microvm
      honstarehand # run manager for pi microvm jobs       
      pi-json-span-processor # aggregates `pi --mode json' event streams into spans
      scripts.compare-flake-pins #compare the pinned revision of various flakerefs in use by my system
      scripts.llm-gcm #generate message for `git commit -m`
      scripts.vipe-sql #evaluate sql for specific databases using `vipe`
      scripts.update-twc-fatp-input #update fatp input for twc and rebuild/push
      scripts.scan-lan #scan hosts visible on LAN
      scripts.pp-psql-table #pretty print one of the tables of the psql service on my machinee
      reload-flakes


    ]);

  shellHook = ''
    export DEFAULT_RELOAD_FLAKES_CONFIG_PATH=${localPkgs.reload-flakes-config}
    exec ${pkgsLib.getExe localPkgs.nushell}
  '';
}
