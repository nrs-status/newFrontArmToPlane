{ pkgsLib, pkgs }:
''
${pkgsLib.getExe pkgs.zoxide} init ${pkgsLib.getExe pkgs.fish} | source
''
