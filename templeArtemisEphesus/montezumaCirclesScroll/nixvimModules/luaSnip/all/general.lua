local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

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
- Create a file called SIGNATURE.json. Fill out the keys of this json file using the following description:
startDatetime: the datetime at the very beginning of this agent session. 
endDatetime: the datetime at the very end of this agent session. 
model: The model that ran these instructions
totalTokens: total API token usage
inputTokens: number of API input tokens used in this session
outputTokens: number of API output tokens used in this session
totalCost: total API cost
inputCost: API cost for input tokens
outputCost: API cost for output tokens
- For some of the information required by SIGNATURE.json, you will need to rely on the `pi` agent harness's report about the current session.
- As the last thing you do, send a `notify-send` notification containing an extremely short description of your task, notifying the user that you've completed your task.
      ]],
      { i(1) },
      { delimiters = "<>" }
    )
  ),
}
