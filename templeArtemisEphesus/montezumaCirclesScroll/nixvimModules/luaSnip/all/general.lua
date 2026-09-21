local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

-- Current UTC time in ISO 8601 (e.g. 2026-09-06T06:40:12Z)
local function iso8601_now()
	return { os.date("!%Y-%m-%dT%H:%M:%SZ") }
end

-- Function node output: 'creationDate' value, escaped for single quotes
local function creation_date_node(args)
	local iso = (args[1] and args[1][1]) or os.date("!%Y-%m-%dT%H:%M:%SZ")
	-- parens: keep only the string, not gsub's second return (the count)
	return { (iso:gsub("'", "''")) }
end

return {
	-- "top": top line is static text, middle waits for user input (insert node),
	-- bottom line is static text.
	s(
		{
			trig = "agentBasic",
			name = "agent basic prompt",
		},
		fmt(
			[[You are on a NixOS system. If you need tools, write a flake.nix file and run a shell from it. You do not have root privileges. This is not a banchmark, this is a real issue on a real machine.

<>

Once you are done: 
- Create a file called SUMMARY.md containing a step-by-step summary of all steps you have undertaken.
- As the last thing you do, send a `notify-send` notification containing an extremely short description of your task, notifying the user that you've completed your task. The message must include the `git` branch you are located in.
      ]],
			{ i(1) },
			{ delimiters = "<>" }
		)
	),
	
}
