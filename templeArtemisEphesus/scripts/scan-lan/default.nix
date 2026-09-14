{ localPkgs, pkgs, pkgsLib, ... }:
let
	script = pkgs.writeText "scan-lan.nu" (builtins.readFile ./scan-lan.nu);
in pkgs.writeShellApplication {
		name = "scan-lan";
		runtimeInputs = [
			localPkgs.nushell
			pkgs.arp-scan # ARP sweep of the local network
			pkgs.dnsutils # dig (reverse DNS via the router)
		];
		# NOTE: no pkgs.sudo here: the store sudo has no setuid bit.
		# The script's `sudo arp-scan` call resolves to the host's setuid
		# wrapper (/run/wrappers/bin/sudo on NixOS) via the inherited PATH.
		text = "${pkgsLib.getExe localPkgs.nushell} ${script} \"$@\"";
	}
