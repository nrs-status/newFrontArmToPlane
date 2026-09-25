-- nvim-key-log.lua
--
-- Neovim side of the nvim-input-test-env.
--
-- It is loaded very early through the command line, e.g.
--
--   nvim --cmd 'lua dofile([[<abs path to this file>]])'
--
-- which the generated `nvim-input-test` wrapper does for you.  Because
-- `--cmd` runs before the nixvim `VIMINIT` (`init.lua`) is sourced, the
-- listener below is installed before the `full` profile loads, so it sees
-- every key Neovim processes afterwards.
--
-- The file is wrapped in a `dofile`-friendly chunk, so it must not `return`
-- anything meaningful.
--
-- For every key Neovim processes it appends one line to $NVIM_INPUT_LOG.
-- Neovim's own documentation for vim.on_key() describes the two arguments:
--
--   key   : the key *after* mappings have been applied (what Neovim
--           effectively "registered")
--   typed : the key(s) *before* mappings were applied (what the user typed)
--
-- Logging both is the whole point: comparing [USER ...] lines written by
-- input-tap.py with the [NVIM ...] lines written here shows exactly how the
-- stream that arrived at the pty was turned into keypresses by Neovim.

local log_path = os.getenv("NVIM_INPUT_LOG")
if log_path == nil or log_path == "" then
  log_path = "/tmp/nvim-input-test-env/nvim-input.log"
end

-- Render a raw keycode string so control characters stay visible.
local function render(s)
  if s == nil then
    return "<nil>"
  end
  local out = {}
  for i = 1, #s do
    local b = s:byte(i)
    if b == 27 then
      out[#out + 1] = "<Esc>"
    elseif b == 13 then
      out[#out + 1] = "<CR>"
    elseif b == 10 then
      out[#out + 1] = "<LF>"
    elseif b == 9 then
      out[#out + 1] = "<Tab>"
    elseif b == 32 then
      out[#out + 1] = "<Space>"
    elseif b == 127 then
      out[#out + 1] = "<BS>"
    elseif b >= 33 and b <= 126 then
      out[#out + 1] = string.char(b)
    else
      out[#out + 1] = string.format("<0x%02x>", b)
    end
  end
  return table.concat(out)
end

local function timestamp()
  return os.date("%H:%M:%S")
end

-- Describe the mapping that turns `lhs` into something else in `mode`, if
-- any.  This is what makes it possible to tell, at a glance, that e.g. a
-- leading `<Space>ww` was resolved to `:w<CR>` rather than being inserted as
-- literal text.
local function mapping_info(lhs, mode)
  if lhs == nil or lhs == "" then
    return ""
  end
  local ok, map = pcall(vim.fn.maparg, lhs, mode, false, true)
  if not ok or type(map) ~= "table" or vim.tbl_isempty(map) then
    return ""
  end
  local remap = ""
  if map.remap then
    remap = " remap"
  end
  return string.format(" maparg(%s)=%s%s", render(lhs), render(map.rhs or ""), remap)
end

local file, err = io.open(log_path, "a")
if file == nil then
  vim.notify("nvim-input-test-env: cannot open " .. log_path .. ": " .. tostring(err), vim.log.levels.ERROR)
  return
end

local ns = vim.api.nvim_create_namespace("nvim-input-test-env/key-log")

vim.on_key(function(key, typed)
  local ok, mode = pcall(function()
    return vim.api.nvim_get_mode().mode
  end)
  if not ok then
    mode = "?"
  end

  -- `typed ~= key` means Neovim expanded a mapping.  Say so explicitly so
  -- the log reads as "what the user pressed" -> "what Neovim registered".
  local resolution = ""
  if typed ~= nil and typed ~= "" and typed ~= key then
    resolution = string.format("  [mapping %s -> %s]", render(typed), render(key))
  end

  local line = string.format(
    "[NVIM %s] mode=%-5s key=%-18s typed=%-18s%s%s\n",
    timestamp(),
    mode,
    render(key),
    render(typed),
    mapping_info(key, mode),
    resolution
  )
  file:write(line)
  file:flush()
end, ns)

file:write(string.format("[NVIM %s] === vim.on_key listener attached (pid=%d) ===\n", timestamp(), vim.fn.getpid()))
file:flush()
