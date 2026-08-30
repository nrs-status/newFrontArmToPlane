return {
  -- "top": top line is static text, middle waits for user input (insert node),
  -- bottom line is static text.
  require("luasnip").s(
    {
      trig = "top",
      name = "top-bottom",
      desc = "Top line, user input, bottom line",
    },
    {
      require("luasnip").t({ "This is the top", "" }),
      require("luasnip").i(1),
      require("luasnip").t({ "", "This is the bottom" }),
    }
  ),
}
