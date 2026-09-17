{ pkgs, ... }:
# gopass: the password manager, pinned to release v1.17.2 ("17.2") from the
# official GitHub releases page (https://github.com/gopasspw/gopass), built
# with the repository's nixpkgs instead of the nixpkgs pin.
pkgs.buildGoModule {
  pname = "gopass";
  version = "1.17.2";

  src = pkgs.fetchFromGitHub {
    owner = "gopasspw";
    repo = "gopass";
    tag = "v1.17.2";
    hash = "sha256-BzYy6STOldUZexty8af3RJy6QD7qsTuN7CC8j04V57c=";
  };

  vendorHash = "sha256-/NW9/lul/ytz8otXqNeJcqbKBBWMJ3wKGrrQciEcXhE=";

  subPackages = [ "." ];

  nativeCheckInputs = [ pkgs.gitMinimal ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=1.17.2"
  ];

  meta.mainProgram = "gopass";
}
