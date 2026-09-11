{ pkgs, ... }:
pkgs.runCommand "scan-and-connect-1.0.0"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta = with pkgs.lib; {
      description = "Locate the lanchamarcou NixOS machine on the LAN and connect over SSH";
      mainProgram = "scan-and-connect";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  }
  ''
    install -Dm555 ${./scan_and_connect.py} $out/share/scan-and-connect.py

    mkdir -p $out/bin
    makeWrapper ${pkgs.python3}/bin/python3 $out/bin/scan-and-connect \
      --add-flags "$out/share/scan-and-connect.py" \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.openssh # ssh
          pkgs.iproute2 # ip (route / addr / neigh)
          pkgs.iputils # ping
        ]
      }
  ''
