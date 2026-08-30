''
if status is-interactive
  source ${builtins.readFile ./workTrunkConfig.fish}
  source ${builtins.readFile ./zoxideConfig.fish}
end
''
