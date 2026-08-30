return {
  require("luasnip").s( { trig = "foo" }, { require("luasnip").t("hello world!")} ),
  require("luasnip").s(
    { trig = "example", desc = "Snippet with fixed top, user input middle, fixed bottom" },
    require("luasnip").sn(nil, {
      require("luasnip").t({ "Top of the lua snippet", "" }),
      require("luasnip").i(1, "your input here"),
      require("luasnip").t({ "", "The bottom of the snippet" }),
    })
  ),
}
