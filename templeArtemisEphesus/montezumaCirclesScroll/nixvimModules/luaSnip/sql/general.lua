local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

-- Subquery letting the database assign the next available id:
-- the nodes table has no default on id, so pick MAX(id) + 1.
local next_id_sql = "(SELECT COALESCE(MAX(id), 0) + 1 FROM nodes)"

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
		t("INSERT INTO nodes (id, title, body, tags, fuzzyaux, creationDate)"),
		t({ "", "VALUES (" }),
		t(next_id_sql), -- let the database pick the next available id
		t(", '"),
		i(1, "title"),
		t("', '"),
		i(2, "body"),
		t("', '"),
		i(3, "tag1,tag2"),
		t("', '"),
		i(4, "fuzzyaux"),
		t("', '"),
		f(creation_date_node, {}),
		t("');"),
	}),
}
