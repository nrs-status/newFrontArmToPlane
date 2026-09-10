{ localPkgs, pkgs, pkgsLib, ... }:
let
	script = pkgs.writeText "llm-gcm.nu" (builtins.readFile ./llm-gcm.nu);
in pkgs.writeShellApplication {
		name = "llm-gcm";
		runtimeInputs = [
			localPkgs.pi 
			localPkgs.neovim
			localPkgs.git
		];
		text = "${pkgsLib.getExe localPkgs.nushell} --config ~/.config/nushell/config.nu ${script} \"$@\"";
	}
