# NixOS VM used to test the battery widget ("BAT n%" / "BAT +n%") of the
# status-stats.sh segment in the two-line tmux status bar, on a real console.
#
# Same skeleton as ../tmux-console-vm/vm.nix (headless boot, serial root
# shell for driving the VM, tmux attached to /dev/tty1 on the VGA card,
# QMP screendumps for the screenshots), plus a *fake battery*:
#
# QEMU has no battery device model, so the guest gets one via
#
#   1. the kernel's test_power module (CONFIG_TEST_POWER=m), which
#      registers power-supply class devices -- and in doing so creates the
#      /sys/class/power_supply directory, which otherwise does not exist in
#      a bare QEMU guest and *cannot be mkdir'd* (sysfs does not allow
#      userspace mkdir).
#   2. a oneshot service that mounts a tmpfs *over*
#      /sys/class/power_supply and populates it with a BAT0 whose
#      capacity/status files can be written from the serial console to
#      flip the widget between the discharging ("BAT n%") and the
#      charging/full ("BAT +n%") display branches.
#
# (test_power's own supply is named test_battery, which status-stats.sh
# intentionally ignores -- real batteries are BAT*; the tmpfs BAT0 is what
# the widget is tested against.)
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
      # host /nix/store mounted read-only into the guest, so the host-built
      # tmux package (with the battery status segment) is available at its
      # exact store path
      virtualisation.mountHostNixStore = true;
      virtualisation.graphics = false; # serial console on stdio, VGA still present
      virtualisation.memorySize = 2048;
      virtualisation.cores = 4;
      virtualisation.diskSize = 4096;

      networking.hostName = "tmux-vm";
      system.stateVersion = "26.11";

      # keep boot noise off the VGA console so the screenshots are readable
      boot.kernelParams = [ "quiet" "loglevel=3" "video=1280x800" ];

      # test_power registers power-supply class devices, which creates
      # /sys/class/power_supply (the mountpoint for the fake battery below)
      boot.kernelModules = [ "test_power" ];

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

      environment.systemPackages = [ localPkgs.tmux ];

      # the fake battery: tmpfs over /sys/class/power_supply with a BAT0
      # whose capacity/status can be rewritten at runtime (from the serial
      # console) to exercise both widget branches.  Depends on test_power
      # having created the mountpoint directory.
      systemd.services.fake-battery = {
        description = "fake battery in /sys/class/power_supply for the tmux battery-widget test";
        after = [ "systemd-modules-load.service" ];
        before = [ "tmux-console.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.util-linux pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # surface failures on the serial console so drive-vm.py sees them
          StandardOutput = "journal+console";
          StandardError = "journal+console";
        };
        script = ''
          for i in $(seq 1 50); do
            [ -d /sys/class/power_supply ] && break
            sleep 0.2
          done
          [ -d /sys/class/power_supply ] || { echo "no /sys/class/power_supply"; exit 1; }
          mount -t tmpfs -o mode=0755 tmpfs /sys/class/power_supply
          mkdir /sys/class/power_supply/BAT0 /sys/class/power_supply/ADP1
          echo BAT > /sys/class/power_supply/BAT0/type
          echo 87 > /sys/class/power_supply/BAT0/capacity
          echo Discharging > /sys/class/power_supply/BAT0/status
          echo Mains > /sys/class/power_supply/ADP1/type
          echo 0 > /sys/class/power_supply/ADP1/online
        '';
      };

      # create the tmux session that is shown on the console (kills the
      # stray "0" session from the `new-session` in inheritedConf.conf)
      systemd.services.tmux-console = {
        description = "create the tmux session shown on the VM console";
        after = [ "fake-battery.service" ];
        wantedBy = [ "multi-user.target" ];
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
    }
  ];
}