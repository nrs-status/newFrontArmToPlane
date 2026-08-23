{
  extraConfigLua =
    builtins.readFile ./diagnosticsDefault.lua
    + "\n"
    + builtins.readFile ./tabKeyFunc.lua;
}
