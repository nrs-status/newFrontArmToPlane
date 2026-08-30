''
if status is-interactive
  set DEBUGVAR 999
  source ${builtins.readFile ./workTrunkConfig.fish}
  source ${builtins.readFile ./zoxideConfig.fish}
end
''
