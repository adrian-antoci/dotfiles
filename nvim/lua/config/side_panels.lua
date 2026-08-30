-- Shared left shell + right OpenCode layout helpers.
-- Remembers panel widths across restarts (per cwd).

local M = {}

local OPENCODE_CMD = "opencode --port"
local applying = false
local pending = nil
local save_timer = nil
local sizes_path = vim.fn.stdpath("state") .. "/side_panel_sizes.json"

---@return table<string, { neotree?: integer, left?: integer, right?: integer }>
local function read_store()
  local f = io.open(sizes_path, "r")
  if not f then
    return {}
  end
  local raw = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  return (ok and type(data) == "table") and data or {}
end

---@param store table
local function write_store(store)
  vim.fn.mkdir(vim.fn.fnamemodify(sizes_path, ":h"), "p")
  local f = io.open(sizes_path, "w")
  if not f then
    return
  end
  f:write(vim.json.encode(store))
  f:close()
end

---@return { neotree?: integer, left?: integer, right?: integer }
local function load_sizes()
  return read_store()[vim.fn.getcwd()] or {}
end

local function collect_sizes()
  local sizes = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      local w = vim.api.nvim_win_get_width(win)
      if ft == "neo-tree" then
        sizes.neotree = w
      else
        local sw = vim.w[win].snacks_win
        if type(sw) == "table" and sw.position == "left" then
          sizes.left = w
        elseif type(sw) == "table" and sw.position == "right" then
          sizes.right = w
        end
      end
    end
  end
  return sizes
end

function M.save_sizes()
  if applying then
    return
  end
  local sizes = collect_sizes()
  if not sizes.neotree and not sizes.left and not sizes.right then
    return
  end
  local store = read_store()
  local prev = store[vim.fn.getcwd()] or {}
  store[vim.fn.getcwd()] = {
    neotree = sizes.neotree or prev.neotree,
    left = sizes.left or prev.left,
    right = sizes.right or prev.right,
  }
  write_store(store)
end

local function schedule_save()
  if save_timer then
    save_timer:stop()
    save_timer = nil
  end
  save_timer = vim.defer_fn(function()
    save_timer = nil
    M.save_sizes()
  end, 200)
end

local function apply_saved_widths()
  local sizes = load_sizes()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      if ft == "neo-tree" and sizes.neotree then
        pcall(vim.api.nvim_win_set_width, win, sizes.neotree)
      else
        local sw = vim.w[win].snacks_win
        if type(sw) == "table" and sw.position == "left" and sizes.left then
          pcall(vim.api.nvim_win_set_width, win, sizes.left)
        elseif type(sw) == "table" and sw.position == "right" and sizes.right then
          pcall(vim.api.nvim_win_set_width, win, sizes.right)
        end
      end
    end
  end
end

---@param count? integer
local function left_opts(count)
  local sizes = load_sizes()
  return {
    cwd = LazyVim.root(),
    count = count or 1,
    win = {
      position = "left",
      width = sizes.left,
      stack = true,
      enter = false,
    },
  }
end

local function opencode_opts()
  local sizes = load_sizes()
  return {
    cwd = LazyVim.root(),
    win = {
      position = "right",
      width = sizes.right,
      enter = false,
    },
  }
end

local function close_all_terminals()
  for _, t in ipairs(Snacks.terminal.list()) do
    if t:buf_valid() then
      pcall(function()
        if t:valid() then
          t:hide()
        end
        vim.api.nvim_buf_delete(t.buf, { force = true })
      end)
    end
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "terminal" then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
end

local function close_neotree()
  local ok, cmd = pcall(require, "neo-tree.command")
  if ok then
    pcall(cmd.execute, { action = "close" })
  end
end

local function ensure_neotree()
  local ok, cmd = pcall(require, "neo-tree.command")
  if not ok then
    return
  end
  local sizes = load_sizes()
  if sizes.neotree then
    pcall(function()
      require("neo-tree").config.window.width = sizes.neotree
    end)
  end
  cmd.execute({
    action = "show",
    source = "filesystem",
    reveal = true,
  })
end

--- Prefer a normal file buffer to keep as the center editor.
local function pick_editor_buf()
  local cur = vim.api.nvim_get_current_buf()
  if vim.bo[cur].buftype == "" and vim.bo[cur].filetype ~= "neo-tree" and vim.bo[cur].filetype ~= "snacks_terminal" then
    return cur
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype == "" then
      local ft = vim.bo[b].filetype
      local name = vim.api.nvim_buf_get_name(b)
      if ft ~= "neo-tree" and ft ~= "snacks_terminal" and name ~= "" then
        return b
      end
    end
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buftype == "" and vim.bo[b].filetype ~= "neo-tree" then
      return b
    end
  end
  return cur
end

local function focus_editor()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    local bt = vim.bo[buf].buftype
    if bt == "" and ft ~= "snacks_terminal" and ft ~= "neo-tree" then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
end

--- Full rebuild: single editor column, then neo-tree + left term + right OpenCode.
local function apply_rebuild()
  local edit_buf = pick_editor_buf()

  close_all_terminals()
  close_neotree()

  -- drop session/split leftovers so layout is clean
  pcall(vim.cmd, "only")
  if vim.api.nvim_buf_is_valid(edit_buf) then
    vim.api.nvim_set_current_buf(edit_buf)
  end

  ensure_neotree()
  Snacks.terminal.open(nil, left_opts())
  Snacks.terminal.open(OPENCODE_CMD, opencode_opts())
  apply_saved_widths()
  focus_editor()
end

--- Soft ensure: show missing panels without wiping the center.
local function apply_soft()
  ensure_neotree()

  local left = select(1, Snacks.terminal.get(nil, vim.tbl_extend("force", left_opts(), { create = false })))
  if left and left:buf_valid() then
    if not left:valid() then
      left:show()
    end
  else
    Snacks.terminal.open(nil, left_opts())
  end

  local right = select(1, Snacks.terminal.get(OPENCODE_CMD, vim.tbl_extend("force", opencode_opts(), { create = false })))
  if right and right:buf_valid() then
    if not right:valid() then
      right:show()
    end
  else
    Snacks.terminal.open(OPENCODE_CMD, opencode_opts())
  end

  apply_saved_widths()
  focus_editor()
end

--- Open (or rebuild) neo-tree + left terminal + right OpenCode.
---@param opts? { force?: boolean, delay?: integer }
function M.ensure(opts)
  opts = opts or {}
  local delay = opts.delay or (opts.force and 120 or 0)

  if pending then
    pending:stop()
    pending = nil
  end

  pending = vim.defer_fn(function()
    pending = nil
    if applying then
      return
    end
    applying = true
    local ok, err = pcall(function()
      if opts.force then
        apply_rebuild()
      else
        apply_soft()
      end
    end)
    applying = false
    if not ok then
      vim.notify("side_panels: " .. tostring(err), vim.log.levels.WARN)
    end
  end, delay)
end

--- Same layout path as a normal nvim start.
function M.startup_layout()
  M.ensure({ force = true, delay = 50 })
end

--- Switch project cwd and apply startup layout (no session restore).
---@param dir string
function M.open_project(dir)
  vim.fn.chdir(dir)
  M.startup_layout()
end

function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("side_panel_sizes", { clear = true })
  vim.api.nvim_create_autocmd("WinResized", {
    group = group,
    callback = schedule_save,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.save_sizes()
    end,
  })
end

M.OPENCODE_CMD = OPENCODE_CMD
M.left_opts = left_opts
M.opencode_opts = opencode_opts

return M
