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
			[[You are on a NixOS system. If you need tools, write a flake.nix file and run a shell from it.

<>

Once you are done: 
- Create a file called SUMMARY.md containing a step-by-step summary of all steps you have undertaken.
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
- As the last thing you do, send a `notify-send` notification containing an extremely short description of your task, notifying the user that you've completed your task. The message must include the `git` branch you are located in.
      ]],
			{ i(1) },
			{ delimiters = "<>" }
		)
	),
	s("nodes_insert", {
		t("INSERT INTO nodes (id, topic, title, body, tags, fuzzyAux, creationDate)"),
		t({ "", "VALUES (" }),
		i(1, "0"), -- id
		t(", '"),
		i(2, "topic"),
		t("', '"),
		i(3, "title"),
		t("', '"),
		i(4, "body"),
		t("', '"),
		i(5, "tag1,tag2"),
		t("', '"),
		i(6, "fuzzyAux"),
		t("', '"),
		f(creation_date_node, {}),
		t("');"),
	}),

	-- Trigger: nodes_id (auto-incremented-looking next id placeholder is manual)
	-- Convenience: just the VALUES row for one node
	s("nodes_row", {
		t("("),
		i(1, "0"),
		t(", '"),
		i(2, "topic"),
		t("', '"),
		i(3, "title"),
		t("', '"),
		i(4, "body"),
		t("', '"),
		i(5, "tag1,tag2"),
		t("', '"),
		i(6, "fuzzyAux"),
		t("', '"),
		f(creation_date_node, {}),
		t(")"),
	}),

	-- Trigger: nodes_select
	s("nodes_select", {
		t("SELECT id, topic, title, body, tags, fuzzyAux, creationDate FROM nodes WHERE id = "),
		i(1, "0"),
		t(";"),
	}),
}
