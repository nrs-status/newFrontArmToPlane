SHARED_DIR=$PWD/workspace/ QEMU_OPTS="-fw_cfg name=opt/prompt,file=/tmp/mytestfile -fw_cfg name=opt/key,file=/run/secrets/OPENROUTER_API_KEY" nix run -f ./provideScript.nix vm-script
