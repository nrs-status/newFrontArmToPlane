{ frontArmToPlane : 
  { registry : (nix registry list | where flakeref == "flake:frontArmToPlane" | get uri.0 | url parse | get params | select 0 2 | transpose -r -d | update lastModified { into datetime -f "%s" } ),
    local : (nix flake metadata --json (cat /run/secrets/paths/wranHearst/frontArmToPlane) | from json | do 
             {let rev = (if ("dirtyRevision" in $in) { git -C /home/sieyes/baghdad_plane/flakes/newFrontArmToPlane rev-parse HEAD~1 }  else { $in | get revision })
               let lastModified = $in | get lastModified | into datetime -f "%s"
               { rev: $rev, lastModified: $lastModified } })
    # local : (nix flake metadata --json /home/sieyes/baghdad_plane/flakes/newFrontArmToPlane/ | from json | select lastModified revision? dirtyRevision? | update lastModified { into datetime -f "%s" } ),
    local_twc_input : (nix flake metadata --json (cat /run/secrets/paths/wranHearst/thatWaterCharmander) | from json | get locks.nodes.frontArmToPlane.locked | select rev lastModified | update lastModified { into datetime -f "%s" } ),
    remote : (nix flake metadata --json github:nrs-status/newFrontArmToPlane | from json | 
      do { let rev = $in | get revision
        let lastModified = $in | get lastModified | into datetime -f "%s"
        { rev : $rev, lastModified: $lastModified } })
  } }
