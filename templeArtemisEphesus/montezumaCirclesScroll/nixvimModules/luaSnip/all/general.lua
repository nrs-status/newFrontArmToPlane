return {
  require("luasnip").s(
    { trig = "example", desc = "Snippet with fixed top, user input middle, fixed bottom" },
    require("luasnip").sn(nil, {
      require("luasnip").t({ "Top of the lua snippet", "" }),
      require("luasnip").i(1),
      require("luasnip").t({ "", "The bottom of the snippet" }),
    })
  ),
}
