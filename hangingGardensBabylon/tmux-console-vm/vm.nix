# NixOS VM used to test the two-line tmux status bar on a real console.
#
# The VM boots headless (serial console on stdio, no graphical window) but
# keeps the default VGA device, so:
#
#   * tmux (the *modified* package from this flake, i.e. with the two-line
#     status bar) is attached to /dev/tty1 -- the Linux console rendered on
#     the VGA card.  getty is masked on tty1 so nothing else fights tmux for
#     the console.
#   * the serial console runs an autologin root shell, which is used to
#     drive / verify the tmux session from outside (`tmux list-windows`,
#     `tmux show -gv status`, ...) and to shut the VM down.
#   * screenshots of the console are taken through QEMU's QMP `screendump`
#     command (a QMP unix socket is added via QEMU_OPTS at run time).
{
  nixosSystem,
  modulesPath,
  pkgs,
  localPkgs,
  ...
}:

nixosSystem {
  system = "x86_64-linux";
  modules = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
    {
      # the host's /nix/store is mounted read-only into the guest, so the
      # host-built tmux package (with the two-line status bar) is available
      # at its exact store path without rebuilding anything in the VM
      virtualisation.mountHostNixStore = true;
      virtualisation.graphics = false; # serial console on stdio, VGA still present
      virtualisation.memorySize = 2048;
      virtualisation.cores = 4;
      virtualisation.diskSize = 4096;

      networking.hostName = "tmux-vm";
      system.stateVersion = "26.11";

      # keep boot noise off the VGA console so the screenshots are readable
      boot.kernelParams = [ "quiet" "loglevel=3" "video=1280x800" ];

      # root shell on the serial console (console=ttyS0 is the primary
      # console in nographic mode)
      services.getty.autologinUser = "root";

      # How tmux gets onto the VGA console: instead of a systemd tty service
      # fighting getty@tty1 for /dev/tty1, root's login shell is a wrapper
      # that simply execs `tmux attach` when it runs on tty1 (and defers to a
      # plain bash everywhere else, e.g. on the serial console).  getty's
      # autologin therefore *brings up* tmux on the console, and if tmux ever
      # detaches, getty restarts and reattaches it.
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

      # wider console font so the status bar has room
      console.packages = [ pkgs.terminus_font ];
      console.font = "ter-132n";

      environment.systemPackages = [ localPkgs.tmux ];

      # create the tmux session that is shown on the console.  NB: the
      # config sources a `new-session` (inheritedConf.conf), which creates a
      # stray session "0" at server start; it is killed here.
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
        '';
      };

      # attach to the VGA console happens via root's shell above; nothing
      # else needed here
    }
  ];
}
