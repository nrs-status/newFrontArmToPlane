{ pkgs, localPkgs, ... }:
pkgs.writeShellScript "pi-bwrapped" ''
${localPkgs.scripts.bwrap-path} \
	--dev /dev \
	--proc /proc \
	--tmpfs /tmp \
	--setenv TMPDIR /tmp \
	--ro-bind /usr /usr \
	--ro-bind /etc /etc \
	--ro-bind /bin /bin \
	--ro-bind /run/secrets/OPENROUTER_API_KEY /run/secrets/OPENROUTER_API_KEY \
	--bind $HOME/.pi $HOME/.pi \
	--bind $PWD $PWD \
	pi "read and execute $PWD/instructions.txt"
''
