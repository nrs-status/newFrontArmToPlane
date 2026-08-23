-- helper function for second function
local function feedkeys_int(keys)
	local feedable_keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
	vim.api.nvim_feedkeys(feedable_keys, 'n', true)
end

-- function determining the behaviour of the tab key
local function check_and_insert_space()
	--get current cursor position
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))

	--get the current line
	local line = vim.api.nvim_get_current_line()

	--check if completion menu is currently open. if it is, call the completion behaviour
	local cmp = require'cmp'
	if cmp.visible() then
		feedkeys_int("<Cmd>lua require('cmp').confirm({select = true})<CR>")
		return
	end

	--check if there's whitespace before the cursor
	local char_before_cursor = line:sub(col,col)
	if char_before_cursor:match("%s") or col == 0 then
		feedkeys_int("<Tab>")
		return
	end
	local ls = require("luasnip")
	if ls.expand_or_jumpable() then
		feedkeys_int("<Plug>luasnip-expand-or-jump")
		return
	end

	feedkeys_int("<Esc>la")
end
vim.keymap.set('i', '<Tab>', check_and_insert_space, {remap = true})
