-- Shared left shell + right OpenCode layout helpers.

local M = {}

local OPENCODE_CMD = "opencode --port"

local function left_opts()
  return {
    cwd = LazyVim.root(),
    count = 1,
    win = {
      position = "left",
      width = 0.15,
      stack = true,
      enter = false,
    },
  }
end

local function opencode_opts()
  return {
    cwd = LazyVim.root(),
    win = {
      position = "right",
      width = 0.15,
      enter = false,
    },
  }
end

---@param position "left"|"right"
local function close_position(position)
  for _, t in ipairs(Snacks.terminal.list()) do
    if t:buf_valid() and t.opts and t.opts.position == position then
      pcall(function()
        if t:valid() then
          t:hide()
        end
        vim.api.nvim_buf_delete(t.buf, { force = true })
      end)
    end
  end
end

--- Focus a normal editing window (not a snacks terminal).
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

--- Open (or recreate) left terminal + right OpenCode for the current root.
---@param opts? { force?: boolean }
function M.ensure(opts)
  opts = opts or {}
  vim.schedule(function()
    if opts.force then
      close_position("left")
      close_position("right")
    end

    -- left shell
    local left = select(1, Snacks.terminal.get(nil, vim.tbl_extend("force", left_opts(), { create = false })))
    if left and left:buf_valid() then
      if not left:valid() then
        left:show()
      end
    else
      Snacks.terminal.open(nil, left_opts())
    end

    -- right OpenCode
    local right = select(1, Snacks.terminal.get(OPENCODE_CMD, vim.tbl_extend("force", opencode_opts(), { create = false })))
    if right and right:buf_valid() then
      if not right:valid() then
        right:show()
      end
    else
      Snacks.terminal.open(OPENCODE_CMD, opencode_opts())
    end

    focus_editor()
  end)
end

M.OPENCODE_CMD = OPENCODE_CMD
M.left_opts = left_opts
M.opencode_opts = opencode_opts

return M
