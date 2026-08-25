--
title: how to update a flake in the registry if it is specified in a nixos module 
creationDate: Tue Aug 25 04:58:10 AM GMT 2026
body: 
a flake in the registry may be pinned to an input used in the nixos flake config. use the `nix flake update <input to update> --flake <flake to update>` to update that specific input. you can omit `--flake ...` if you are in the same directory
--

