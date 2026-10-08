-- Always-visible, top-right floating toolbar (Android-Studio-style): shows the
-- selected run config + device and a Play button that toggles to Stop while the
-- app runs (plus Debug, and Hot Reload / Hot Restart while a Flutter app runs).
-- Clickable with the mouse and mirrored by <leader>r*.
-- While the Dart analysis server is busy, an "Analyzing…" segment is prepended.

local M = {}

M.win = nil
M.buf = nil
M.ns = vim.api.nvim_create_namespace("runconfig_toolbar")
M.regions = {} -- { {lo=cell, hi=cell, action=string}, ... } for mouse hit-testing
M.col = 0
M.width = 0

--- Ordered display segments for the current state.
---@return { text:string, hl:string, action:string? }[]
local function segments()
  local rc = require("runconfig")
  local kind = rc.project_type()
  local running = rc.is_running()
  local config = rc.selected.config or "no config"
  local device = rc.selected.device and rc.selected.device.name or "no device"
  local segs = {
    { text = " " .. kind .. " ", hl = "RunConfigKind" },
    { text = "\u{2502}", hl = "RunConfigSep" },
  }
  if kind == "Flutter" and require("runconfig.analysis").is_analyzing() then
    segs[#segs + 1] = { text = " \u{f110} Analyzing\u{2026} ", hl = "RunConfigAnalyzing" }
    segs[#segs + 1] = { text = "\u{2502}", hl = "RunConfigSep" }
  end
  segs[#segs + 1] = { text = " \u{f135} " .. config .. " ", hl = "RunConfigCfg", action = "config" }
  segs[#segs + 1] = { text = "\u{2502}", hl = "RunConfigSep" }
  if kind == "Flutter" then
    segs[#segs + 1] = { text = " \u{f109} " .. device .. " ", hl = "RunConfigDev", action = "device" }
    segs[#segs + 1] = { text = "\u{2502}", hl = "RunConfigSep" }
  end
  if running then
    if kind == "Flutter" then
      segs[#segs + 1] = { text = " \u{f0e7} ", hl = "RunConfigReload", action = "reload" }
      segs[#segs + 1] = { text = " \u{f2f1} ", hl = "RunConfigRestart", action = "restart" }
      segs[#segs + 1] = { text = " \u{f013} ", hl = "RunConfigTools", action = "devmenu" }
    end
    segs[#segs + 1] = { text = " \u{f04d} ", hl = "RunConfigStop", action = "toggle" }
  else
    segs[#segs + 1] = { text = " \u{f04b} ", hl = "RunConfigRun", action = "toggle" }
    segs[#segs + 1] = { text = " \u{f188} ", hl = "RunConfigDebug", action = "debug" }
  end
  return segs
end

--- Create the buffer + float if needed, ensuring it lives in the current tab.
local function ensure()
  if not (M.buf and vim.api.nvim_buf_is_valid(M.buf)) then
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.buf].bufhidden = "hide"
  end
  local tab = vim.api.nvim_get_current_tabpage()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    if vim.api.nvim_win_get_tabpage(M.win) == tab then return end
    pcall(vim.api.nvim_win_close, M.win, true)
  end
  M.win = vim.api.nvim_open_win(M.buf, false, {
    relative = "editor", width = 1, height = 1, row = 0, col = vim.o.columns - 1,
    focusable = false, style = "minimal", zindex = 250, noautocmd = true,
  })
  vim.wo[M.win].winhl = "Normal:RunConfigBar"
end

---@param w integer display width in cells
local function resize(w)
  w = math.max(1, math.min(w, vim.o.columns))
  M.width, M.col = w, math.max(0, vim.o.columns - w)
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_set_config(M.win, {
      relative = "editor", row = 0, col = M.col, width = w, height = 1,
    })
  end
end

--- Rebuild the toolbar contents, highlights and geometry.
function M.render()
  local segs = segments()
  local line, cell = "", 0
  M.regions = {}
  for _, s in ipairs(segs) do
    local w = vim.api.nvim_strwidth(s.text)
    if s.action then M.regions[#M.regions + 1] = { lo = cell, hi = cell + w, action = s.action } end
    line, cell = line .. s.text, cell + w
  end
  ensure()
  if not (M.buf and vim.api.nvim_buf_is_valid(M.buf)) then return end
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, { line })
  vim.bo[M.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(M.buf, M.ns, 0, -1)
  local b = 0
  for _, s in ipairs(segs) do
    local e = b + #s.text
    vim.api.nvim_buf_set_extmark(M.buf, M.ns, 0, b, { end_col = e, hl_group = s.hl })
    b = e
  end
  resize(cell)
end

---@param action string
local function dispatch(action)
  local rc = require("runconfig")
  vim.schedule(function()
    if action == "config" then
      rc.select_config()
    elseif action == "device" then
      rc.select_device()
    elseif action == "debug" then
      rc.run(true)
    elseif action == "reload" then
      rc.reload()
    elseif action == "restart" then
      rc.restart()
    elseif action == "devmenu" then
      rc.dev_menu()
    elseif action == "toggle" then
      if rc.is_running() then rc.stop() else rc.run(false) end
    end
  end)
end

--- <LeftMouse> handler: act on toolbar clicks, otherwise pass the click through.
function M.on_mouse()
  local pos = vim.fn.getmousepos()
  if M.win and vim.api.nvim_win_is_valid(M.win)
    and pos.screenrow == 1
    and pos.screencol > M.col and pos.screencol <= M.col + M.width then
    local off = pos.screencol - M.col - 1
    for _, r in ipairs(M.regions) do
      if off >= r.lo and off < r.hi then dispatch(r.action) end
    end
    return ""
  end
  return "<LeftMouse>"
end

--- (Default) highlight groups for the toolbar.
function M.setup_highlights()
  local set = vim.api.nvim_set_hl
  set(0, "RunConfigBar", { link = "StatusLine", default = true })
  set(0, "RunConfigKind", { link = "Type", default = true })
  set(0, "RunConfigCfg", { link = "Function", default = true })
  set(0, "RunConfigDev", { link = "Constant", default = true })
  set(0, "RunConfigSep", { link = "Comment", default = true })
  set(0, "RunConfigAnalyzing", { link = "DiagnosticWarn", default = true })
  set(0, "RunConfigRun", { fg = "#a6e3a1", bold = true, default = true })
  set(0, "RunConfigDebug", { fg = "#fab387", bold = true, default = true })
  set(0, "RunConfigReload", { fg = "#f9e2af", bold = true, default = true })
  set(0, "RunConfigRestart", { fg = "#89b4fa", bold = true, default = true })
  set(0, "RunConfigTools", { fg = "#cba6f7", bold = true, default = true })
  set(0, "RunConfigStop", { fg = "#f38ba8", bold = true, default = true })
end

--- Register highlights, mouse mapping and the autocmds that keep it visible.
function M.setup()
  M.setup_highlights()
  local grp = vim.api.nvim_create_augroup("runconfig_toolbar", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = grp, callback = M.setup_highlights })
  vim.api.nvim_create_autocmd({ "VimResized", "TabEnter" }, {
    group = grp,
    callback = function() M.render() end,
  })
  vim.keymap.set("n", "<LeftMouse>", M.on_mouse, { expr = true, desc = "runconfig toolbar click" })
  vim.schedule(function() M.render() end)
end

return M
