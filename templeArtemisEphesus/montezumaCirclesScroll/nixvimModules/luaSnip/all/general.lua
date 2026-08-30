local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  -- "top": top line is static text, middle waits for user input (insert node),
  -- bottom line is static text.
  s(
    {
      trig = "top",
      name = "top-bottom",
      desc = "Top line, user input, bottom line",
    },
    {
      t({ "This is the top", "" }),
      i(1),
      t({ "", "This is the bottom" }),
    }
  ),
}
