-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local side = require("config.side_panels")

local function next_left_term_count()
  local used = {}
  for _, t in ipairs(Snacks.terminal.list()) do
    local meta = vim.b[t.buf] and vim.b[t.buf].snacks_terminal
    if meta and meta.id then
      used[meta.id] = true
    end
  end
  local n = 1
  while used[n] do
    n = n + 1
  end
  return n
end

local function left_terminals()
  local left = {}
  for _, t in ipairs(Snacks.terminal.list()) do
    if t:buf_valid() and t.opts and t.opts.position == "left" then
      left[#left + 1] = t
    end
  end
  return left
end

local function any_left_term_visible()
  for _, t in ipairs(left_terminals()) do
    if t:valid() then
      return true
    end
  end
  return false
end

-- <leader>t : open left terminal; press again to add another terminal in the same column
vim.keymap.set("n", "<leader>t", function()
  local count = any_left_term_visible() and next_left_term_count() or 1
  -- reuse hidden #1 if nothing visible
  if count == 1 then
    local existing = select(1, Snacks.terminal.get(nil, vim.tbl_extend("force", side.left_opts(1), { create = false })))
    if existing and existing:buf_valid() and not existing:valid() then
      existing:show()
      return
    end
  end
  Snacks.terminal.open(nil, side.left_opts(count))
end, { desc = "Terminal left (add)" })

-- <leader>T : hide/show the left terminal stack
vim.keymap.set("n", "<leader>T", function()
  local left = left_terminals()
  if #left == 0 then
    Snacks.terminal.open(nil, side.left_opts(1))
    return
  end
  local open = false
  for _, t in ipairs(left) do
    if t:valid() then
      open = true
      break
    end
  end
  for _, t in ipairs(left) do
    if open then
      t:hide()
    else
      t:show()
    end
  end
end, { desc = "Terminal left (toggle)" })
