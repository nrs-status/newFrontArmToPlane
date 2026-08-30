local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  -- "top": top line is static text, middle waits for user input (insert node),
  -- bottom line is static text.
  s(
    {
      trig = "agentBasic",
      name = "agent basic prompt",
    }, fmt(
      [[You are on a NixOS system. If you need tools, write a flake.nix file and run a shell from it.

      <>

Once you are done: 
- Provide a step-by-step summary of all steps you have undertaken.
- Create a file called SIGNATURE.md containing the current date, the name of the model that ran these instructions, the total API token usage and the total total API costs. In order to obtain the API costs, rely on the pi coding agent's report about the current session.

      ]],
      { i(1) },
      { delimiters = "<>" }
    )
  ),
}
