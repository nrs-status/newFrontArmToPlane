use std/config *

# Initialize the PWD hook as an empty list if it doesn't exist
$env.config.hooks.env_change.PWD = $env.config.hooks.env_change.PWD? | default []

$env.config.hooks.env_change.PWD ++= [{||
  if (which direnv | is-empty) {
    # If direnv isn't installed, do nothing
    return
  }

  direnv export json | from json | default {} | update cells --columns [ PATH ] {
    # If direnv changes the PATH, it will become a string and we need to re-convert it to a list
    do (env-conversions).path.from_string $in
  } | load-env
}]
