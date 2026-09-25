# NixOS VM used to visually check the gruvbox-consistent tmux status bar on
# a real Linux console.
#
# Same skeleton as ../tmux-console-vm/vm.nix (headless boot, serial root
# shell for driving the VM, tmux attached to /dev/tty1 on the VGA card, QMP
# screendumps for the screenshots).  Two additions are needed for this test:
#
#   * pkgs.procps is added to the tmux server's PATH, because the REC marker
#     uses `pgrep -F'; the systemd-started server otherwise only gets the
#     path listed in the service below.
#   * the session is created with real taskmux (so `taskmux done' can flip
#     the DONE marker) and the guest gets taskmux on PATH.
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
      # host-built tmux package (with the gruvbox-consistent status bar) and
      # the taskmux package are available at their exact store paths without
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
      # 8x16 font: gives the 1280px console ~160 columns, wide enough to
      # show the full right-hand status stack (stats + date/time + hostname +
      # REC/PREFIX chips) without clipping; the previous 10x20 font left the
      # console at ~106 columns, which is narrower than a real terminal.
      console.font = "ter-116n";

      environment.systemPackages = [
        localPkgs.tmux
        taskmuxPkg
      ];

      # create the tmux session shown on the console (kills the stray "0"
      # session from the `new-session` in inheritedConf.conf) and mark its
      # task as *underway* with the real taskmux: the initial state must not
      # show the DONE indicator; drive-vm.py flips it with `taskmux done'.
      systemd.services.tmux-console = {
        description = "create the tmux session shown in the VM console";
        wantedBy = [ "multi-user.target" ];
        # the tmux server inherits this PATH: the gruvbox plugin and the
        # other tmux plugin run-shell scripts call the `tmux` binary
        # unqualified; status-stats.sh needs awk/grep/coreutils and the REC
        # marker needs pgrep, so all of those are provided here for a
        # systemd-started server.
        path = [
          localPkgs.tmux
          taskmuxPkg
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gawk
          pkgs.procps
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
          ${taskmuxPkg}/bin/taskmux start "gruvbox consistency test" work
        '';
      };
    }
  ];
}
