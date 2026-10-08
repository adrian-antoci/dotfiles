-- Android-Studio-style run manager for Flutter: a persistent run-config selector
-- and device selector that you set once, plus a single Run/Debug action that
-- combines both. Selections persist per project across sessions and are shown in
-- the top-right toolbar. Built on top of flutter-tools.nvim.

local launch_json = require("runconfig.launch_json")
local rust = require("runconfig.rust")

local M = {}

--- Current selection (config = run configuration name; device = RunTarget).
M.selected = { config = nil, device = nil }

local configs_cache, configs_root
local loaded_root

--- Workspace root: the directory with VS Code or Android Studio run configs
--- (falling back to nvim's cwd). Selections and configs are keyed off this.
---@return string
function M.root()
  local buf = vim.api.nvim_buf_get_name(0)
  local start = (buf ~= "" and vim.fs.dirname(buf)) or vim.uv.cwd()
  local git = vim.fs.find(".git", { upward = true, path = start })[1]
  -- stop is not searched, so pass the parent of the git root or Cargo.toml
  -- sitting next to .git is never found.
  local git_root = git and vim.fs.dirname(git)
  local cargo = vim.fs.find("Cargo.toml", {
    upward = true,
    path = start,
    stop = git_root and vim.fs.dirname(git_root) or nil,
  })[1]
  if cargo then
    local cargo_root = vim.fs.dirname(cargo)
    if rust.is_server(cargo_root) then return cargo_root end
  end
  return launch_json.find_root(start) or launch_json.find_root(vim.uv.cwd()) or vim.uv.cwd()
end

function M.is_rust()
  return rust.is_server(M.root())
end

--- "Rust", "Flutter", or "Unknown" for the current buffer.
function M.project_type()
  if M.is_rust() then return "Rust" end
  local buf = vim.api.nvim_buf_get_name(0)
  local start = (buf ~= "" and vim.fs.dirname(buf)) or vim.uv.cwd()
  if vim.fs.find("pubspec.yaml", { upward = true, path = start })[1] then return "Flutter" end
  return "Unknown"
end

function M.is_running()
  if M.is_rust() then return rust.is_running() end
  local ok, commands = pcall(require, "flutter-tools.commands")
  return ok and commands.is_running()
end

--- Run configurations from VS Code and Android Studio (cached per root).
---@return table[]
function M.configs()
  local root = M.root()
  if configs_root ~= root then
    configs_cache = rust.is_server(root) and rust.configs(root) or launch_json.parse(root)
    configs_root = root
  end
  return configs_cache or {}
end

--- The flutter.ProjectConfig for the selected config name (a fresh copy), or nil.
---@return table?
function M.selected_config_conf()
  if not M.selected.config then return nil end
  for _, c in ipairs(M.configs()) do
    if c.name == M.selected.config then return vim.deepcopy(c) end
  end
  return nil
end

--- Re-render the toolbar so it reflects the latest selection / run state.
function M.refresh()
  vim.schedule(function() pcall(require("runconfig.toolbar").render) end)
end

--- Poll-refresh the toolbar a handful of times. flutter run/quit is async, so
--- `is_running()` flips a beat after we trigger it; a short burst guarantees the
--- Play/Stop button settles on the real state without waiting for an event.
function M.refresh_burst()
  local tries = 0
  local timer = assert(vim.uv.new_timer())
  timer:start(120, 200, function()
    tries = tries + 1
    M.refresh()
    if tries >= 8 then
      timer:stop()
      timer:close()
    end
  end)
end

--- Restore the persisted selection for the current project.
function M.load()
  local root = M.root()
  local sel = require("runconfig.state").load(root)
  if sel.config then
    local exists = false
    for _, c in ipairs(M.configs()) do
      if c.name == sel.config then exists = true end
    end
    sel.config = exists and sel.config or nil
  end
  M.selected.config = sel.config
  M.selected.device = sel.device
  if not M.selected.config then
    local configs = M.configs()
    if configs[1] then M.selected.config = configs[1].name end
  end
  loaded_root = root
end

--- Persist the current selection for the current project.
function M.save()
  require("runconfig.state").save(M.root(), {
    config = M.selected.config,
    device = M.selected.device,
  })
end

--- Open the run-configuration picker (sets/persists the choice only).
function M.select_config()
  local configs = M.configs()
  if #configs == 0 then
    return vim.notify("No run configurations found", vim.log.levels.WARN)
  end
  require("runconfig.pickers").pick_config(configs, function(cfg)
    M.selected.config = cfg.name
    M.save()
    M.refresh()
  end)
end

--- Open the device picker. Shows cached devices instantly, then refreshes the
--- list live as devices load / connect / disconnect, with a loading indicator in
--- the picker title. Sets and persists the choice on confirm.
function M.select_device()
  local devices = require("runconfig.devices")

  -- Live item list: seed from cache so the picker opens instantly, then mutate
  -- this same table in place and re-run the picker's finder on changes.
  local items = vim.list_extend({}, devices.cached())
  local picker, unsub, stop_watch

  local function cleanup()
    if unsub then unsub() end
    if stop_watch then stop_watch() end
    unsub, stop_watch = nil, nil
  end

  picker = require("runconfig.pickers").pick_device(items, function(target)
    cleanup()
    if target then
      M.selected.device = target
      M.save()
      M.refresh()
    end
  end)

  -- Swap the picker's items in place and re-render its list.
  local function apply(targets)
    for i = #items, 1, -1 do
      items[i] = nil
    end
    vim.list_extend(items, targets)
    if picker and not picker.closed then picker:find({ refresh = true }) end
  end

  -- Toggle the loading hint in the picker title while a fetch is in flight.
  local function set_loading(loading)
    if not (picker and not picker.closed) then return end
    picker.title = loading and "Select device \u{2026} loading" or "Select device"
    pcall(function() picker:update_titles() end)
  end

  -- Keep the open picker in sync with device connect/disconnect events.
  unsub = devices.subscribe(apply)
  stop_watch = devices.start_watch(2500)

  -- Kick an immediate fresh fetch (updates cache -> apply via the subscription).
  set_loading(true)
  devices.list(function(targets)
    set_loading(false)
    if #targets == 0 and picker and not picker.closed then
      vim.notify("No devices or emulators found", vim.log.levels.WARN)
    end
  end)
end

--- Empty the flutter dev-log buffer (if it exists) so each run starts with a
--- clean console, like Android Studio.
local function clear_dev_log()
  local bufnr = vim.fn.bufnr("__FLUTTER_DEV_LOG__")
  if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then return end
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.bo[bufnr].modifiable = false
  vim.b[bufnr].flutter_dev_log_lastcount = 0
end

--- Run (or debug) using the selected run config + device.
---@param force_debug boolean?
function M.run(force_debug)
  if M.is_rust() then
    rust.run(M.root(), M.selected_config_conf(), force_debug)
    return
  end
  local commands = require("flutter-tools.commands")
  if commands.is_running() then return vim.notify("Flutter is already running!") end

  local function start(device_id)
    clear_dev_log()
    local conf = M.selected_config_conf() or {}
    if device_id then conf.device = device_id end
    commands.run({ force_debug = force_debug or false }, next(conf) and conf or nil)
    M.refresh_burst()
  end

  local device = M.selected.device
  if not device then
    start(nil)
  elseif device.running then
    start(device.id)
  else
    vim.notify("Starting emulator " .. device.name .. "\u{2026}")
    require("runconfig.devices").launch_and_wait(device, function(id)
      if id then
        start(id)
      else
        vim.notify("Emulator did not start in time", vim.log.levels.ERROR)
      end
    end)
  end
end

function M.debug() M.run(true) end

--- Close the flutter dev-log console window/buffer (named __FLUTTER_DEV_LOG__),
--- so stopping the app also tears down its output console like Android Studio.
local function close_dev_log()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf):match("__FLUTTER_DEV_LOG__$") then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  local bufnr = vim.fn.bufnr("__FLUTTER_DEV_LOG__")
  if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

--- Toggle the Flutter dev-log console like Android Studio's ⌘4: hide it if a
--- window is showing it, otherwise re-open the existing log buffer in a bottom
--- split (edgy docks it as the bottom tool panel). No-op until a log exists.
function M.toggle_dev_log()
  if M.is_rust() then return rust.toggle_log() end
  local bufnr = vim.fn.bufnr("__FLUTTER_DEV_LOG__")
  if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return vim.notify("No Flutter dev log yet (run the app first)", vim.log.levels.INFO)
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      pcall(vim.api.nvim_win_close, win, false)
      return
    end
  end
  vim.cmd("botright 15split")
  vim.api.nvim_win_set_buf(0, bufnr)
end

--- Mirror an Android device on screen with scrcpy (like Android Studio's Device
--- Mirroring), targeting the given adb serial. scrcpy must be on $PATH.
---@param device RunTarget
local function mirror_android(device)
  if vim.fn.executable("scrcpy") == 0 then
    return vim.notify("scrcpy not found on PATH (install with: brew install scrcpy)", vim.log.levels.ERROR)
  end
  vim.notify("Mirroring " .. device.name .. " \u{2026}")
  vim.system({ "scrcpy", "-s", device.id, "--window-title", device.name }, { detach = true })
end

--- Mirror an iOS device by opening a QuickTime "New Movie Recording" window.
--- QuickTime's source (the iPhone) can't be selected programmatically, so pick
--- the device from the recording window's dropdown once; QuickTime then keeps it
--- as the default source for later recordings. USB connection required.
local function mirror_ios()
  vim.notify("Opening QuickTime \u{2013} pick your iPhone from the recording dropdown", vim.log.levels.INFO)
  vim.system({
    "osascript", "-e",
    'tell application "QuickTime Player"\n'
      .. "  activate\n"
      .. "  if not (exists document 1) then new movie recording\n"
      .. "end tell",
  }, { detach = true })
end

--- Mirror the selected device on screen, Android-Studio-style. Platform-aware:
--- Android uses scrcpy; iOS opens a QuickTime movie-recording window. No-op with
--- a hint for unsupported platforms or when no device is selected.
function M.mirror_device()
  local device = M.selected.device
  if not device then
    return vim.notify("No device selected (pick one first with <leader>rf)", vim.log.levels.WARN)
  end
  local platform = tostring(device.platform or ""):lower()
  if platform:find("android") then
    mirror_android(device)
  elseif platform:find("ios") then
    mirror_ios()
  else
    vim.notify("Device mirroring is only supported for Android and iOS", vim.log.levels.WARN)
  end
end

--- Stop the running app and tear down its console. Safe to call when nothing is
--- running (still clears any stale console window).
function M.stop()
  if M.is_rust() then
    rust.stop()
    return
  end
  local commands = require("flutter-tools.commands")
  if commands.is_running() then commands.quit() end
  vim.defer_fn(function()
    close_dev_log()
    M.refresh_burst()
  end, 150)
end

function M.reload()
  if M.is_rust() then return end
  require("flutter-tools.commands").reload()
end
function M.restart()
  if M.is_rust() then return end
  require("flutter-tools.commands").restart()
end

--- Open a menu of Flutter dev-tools toggles that act on the running app (debug
--- paint / layout bounds, widget inspector, DevTools, platform, brightness).
--- Only meaningful while the app is running.
function M.dev_menu()
  local commands = require("flutter-tools.commands")
  if not commands.is_running() then
    return vim.notify("Flutter is not running", vim.log.levels.WARN)
  end
  require("runconfig.pickers").pick_dev_tool({
    { icon = "\u{f1fc}", label = "Debug paint (layout bounds)", run = function() commands.visual_debug() end },
    { icon = "\u{f002}", label = "Widget inspector (select mode)", run = function() commands.inspect_widget() end },
    { icon = "\u{f188}", label = "Paint baselines", run = function() commands.paint_baselines() end },
    { icon = "\u{f0e7}", label = "Open DevTools (browser)", run = function() commands.open_dev_tools() end },
    { icon = "\u{f2d0}", label = "Toggle platform (Android/iOS)", run = function() commands.change_target_platform() end },
    { icon = "\u{f042}", label = "Toggle brightness (light/dark)", run = function() commands.brightness() end },
  })
end

--- Initialise the toolbar, restore persisted selection, and keep the toolbar in
--- sync with flutter-tools run/stop events.
function M.setup()
  require("runconfig.toolbar").setup()
  require("runconfig.analysis").setup()
  M.load()
  local grp = vim.api.nvim_create_augroup("runconfig", { clear = true })
  -- FlutterToolsAppStarted fires on run; PROJECT_CONFIG_CHANGED is also emitted
  -- by flutter-tools' shutdown() (including when the app exits on its own), so
  -- these cover both start and stop transitions.
  vim.api.nvim_create_autocmd("User", {
    group = grp,
    pattern = { "FlutterToolsAppStarted", "FlutterToolsProjectConfigChanged" },
    callback = function() M.refresh_burst() end,
  })
  -- Re-load the persisted selection when moving into a Dart buffer that belongs
  -- to a different project root (e.g. nvim was started outside the project).
  vim.api.nvim_create_autocmd("FileType", {
    group = grp,
    pattern = { "dart", "rust" },
    callback = function()
      if M.root() ~= loaded_root then
        M.load()
        M.refresh()
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = grp,
    callback = function() pcall(M.save) end,
  })
  -- Lock the flutter dev-log window to its buffer so opening a file (neo-tree,
  -- pickers, :edit) never replaces the log with your file. winfixbuf makes
  -- Neovim skip this window when choosing where to open a buffer.
  -- Also colorize the log's ANSI escape codes with baleia so Flutter's coloured
  -- output renders as real colours instead of raw sequences (e.g. ^[[38;5;3m).
  local baleia_attached = {}
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
    group = grp,
    pattern = "*__FLUTTER_DEV_LOG__",
    callback = function(ev)
      for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
        pcall(vim.api.nvim_set_option_value, "winfixbuf", true, { win = win })
      end
      if not baleia_attached[ev.buf] then
        local ok, baleia = pcall(require, "baleia")
        if ok then
          baleia.setup({}).automatically(ev.buf)
          baleia_attached[ev.buf] = true
        end
      end
    end,
  })
end

return M
