inputs:
{
  bare = import ./bare.nix inputs;

  # new vm derived from `bare` via `extendModules`, adding one single new
  # service that calls `pi --mode json` with a string found in the vm's
  # /sys/firmware/qemu_fw_cfg and streams the output to a unix socket the
  # host can read
  wservice = import ./wservice.nix inputs;
}
