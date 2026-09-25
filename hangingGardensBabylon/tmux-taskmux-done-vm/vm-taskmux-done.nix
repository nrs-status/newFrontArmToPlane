# NixOS VM used to test the tmux taskmux-done status-bar indicator
# (status-taskmux-done.sh: a green " DONE" segment immediately to the left
# of the CPU/RAM/temperature stats module, shown only while `taskmux list'
# would display at least one task that is done) on a real console.
#
# Same skeleton as ../tmux-console-vm/vm.nix (headless boot, serial root
# shell for driving the VM, tmux attached to /dev/tty1 on the VGA card,
# QMP screendumps for the screenshots).  Additionally the guest gets the
# *taskmux* package (built from the nasExitGiScorp.taskmux-for-tmux
# worktree, see ./provideScript.nix) so the task state can be created with
# the real taskmux commands (`taskmux start' / `taskmux done' / `taskmux
# clear') both from the tmux-console service and from the serial console.
{
  nixosSystem,
  modulesPath,
  pkgs,
  localPkgs,
  taskmuxPkg,
  ...
}:

nixosSystem {
  system = "x86_64-linux";
  modules = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
    {
      # the host's /nix/store is mounted read-only into the guest, so the
      # host-built tmux package (with the taskmux-done indicator) and the
      # taskmux package are available at their exact store paths without
      # rebuilding anything in the VM
      virtualisation.mountHostNixStore = true;
      virtualisation.graphics = false; # serial console on stdio, VGA still present
      virtualisation.memorySize = 2048;
      virtualisation.cores = 4;
      virtualisation.diskSize = 4096;

      networking.hostName = "tmux-vm";
      system.stateVersion = "26.11";

      # keep boot noise off the VGA console so the screenshots are readable
      boot.kernelParams = [ "quiet" "loglevel=3" "video=1280x800" ];

      # root shell on the serial console
      services.getty.autologinUser = "root";

      # tmux on the VGA console: root's login shell execs `tmux attach` on
      # tty1 (plain bash elsewhere, e.g. on the serial console)
      users.users.root = {
        shell = (pkgs.writeShellScriptBin "root-shell" ''
          if [ "$(${pkgs.coreutils}/bin/tty)" = "/dev/tty1" ]; then
            until ${localPkgs.tmux}/bin/tmux -u has-session -t work 2>/dev/null; do
              sleep 1
            done
            exec ${localPkgs.tmux}/bin/tmux -u attach -t work
          fi
          exec ${pkgs.bashInteractive}/bin/bash
        '').overrideAttrs (old: { passthru.shellPath = "/bin/root-shell"; });
      };

      console.packages = [ pkgs.terminus_font ];
      console.font = "ter-132n";

      environment.systemPackages = [
        localPkgs.tmux
        taskmuxPkg
      ];

      # create the tmux session that is shown on the console (kills the
      # stray "0" session from the `new-session` in inheritedConf.conf) and
      # mark it as having a task *underway* with the real taskmux: the
      # initial state must not show the DONE indicator (only a done task
      # may show it); drive-vm.py flips the state with `taskmux done'.
      systemd.services.tmux-console = {
        description = "create the tmux session shown on the VM console";
        wantedBy = [ "multi-user.target" ];
        # the tmux server inherits this PATH: the gruvbox plugin and the
        # other tmux plugin run-shell scripts call the `tmux` binary
        # unqualified, and status-stats.sh needs awk/grep/coreutils; on a
        # normal interactive host the server PATH already provides them, but
        # a systemd-started server would otherwise have an empty PATH
        path = [
          localPkgs.tmux
          taskmuxPkg
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gawk
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          TMUX="${localPkgs.tmux}/bin/tmux -u"
          $TMUX new-session -d -s work -n bash
          $TMUX list-sessions -F '#{session_name}' \
            | ${pkgs.gnugrep}/bin/grep -vx work \
            | while read -r s; do $TMUX kill-session -t "$s"; done
          $TMUX new-window -d -t work -n editor
          $TMUX new-window -d -t work -n logs
          $TMUX select-window -t work:1
          ${taskmuxPkg}/bin/taskmux start "vm console task" work
        '';
      };
    }
  ];
}