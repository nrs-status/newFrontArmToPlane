def main [--push-fatp, --rebuild] {
  echo $push_fatp
  echo $rebuild
  let initialPath = $env.PWD
  if $push_fatp {
    cd $env.FRONTARMTOPLANE_PATH
    git push -u origin main
  }
  cd $env.THATWATERCHARMANDER_PATH
  sudo nix flake update frontArmToPlane
  sudo git add ./flake.lock
  sudo git commit -m "updating lockfile's frontArmToPlane input" ./flake.lock
  if $rebuild {
    sudo nixos-rebuild switch --flake .#wranHearst
  }

  cd $initialPath
}
