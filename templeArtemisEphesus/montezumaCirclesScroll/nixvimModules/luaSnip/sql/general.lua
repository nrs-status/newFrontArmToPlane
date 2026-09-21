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
