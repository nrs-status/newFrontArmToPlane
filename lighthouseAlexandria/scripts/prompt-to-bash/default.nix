{ localPkgs, pkgs, ... }:
# prompt-to-bash: reads a transcribed voice command from stdin, asks the pi
# coding agent to translate it into a list of bash commands, pipes the result
# through `vipe' so the user can review/edit it, and finally executes the
# commands one after the other.  Depends on the flake's `pi' package and on
# `vipe' (from moreutils) at runtime.
pkgs.runCommand "prompt-to-bash-1.0.0"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta = with pkgs.lib; {
      description =
        "Translate a voice-command transcript into bash commands via the pi coding agent, review with vipe, then execute";
      mainProgram = "prompt-to-bash";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  }
  ''
    install -Dm555 ${./prompt-to-bash.py} $out/share/prompt-to-bash.py

    mkdir -p $out/bin
    makeWrapper ${pkgs.python3}/bin/python3 $out/bin/prompt-to-bash \
      --add-flags "$out/share/prompt-to-bash.py" \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          localPkgs.pi # pi coding harness (default --pi-path)
          pkgs.moreutils # provides `vipe' (default --vipe-path)
        ]
      }
  ''
