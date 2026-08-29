local ls = require("luasnip")

return {
  ls.s(
    { trig = "example", desc = "Snippet with fixed top, user input middle, fixed bottom" },
    ls.snippet_node(nil, {
      ls.t({ "Top of the lua snippet", "" }),
      ls.i(1, "your input here"),
      ls.t({ "", "The bottom of the snippet" }),
    })
  ),
}
