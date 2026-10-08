-- Run/debug a Rust crate from the toolbar. The crate root is the nearest
-- Cargo.toml. Bins come from [[bin]], src/main.rs, and src/bin/*.rs. Optional
-- .vscode/launch.json and .env* files override the inferred Dev/Prod presets.

local M = {}

local LOG = "__RUST_LOG__"

M.handle = nil
M.running = false

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then return nil end
  local text = fd:read("*a")
  fd:close()
  return text
end

local function scan_manifest(text)
  local pkg, bins, members = nil, {}, {}
  local section, collecting = nil, nil
  local function finish_array(line)
    if not collecting then return line end
    collecting.buf = collecting.buf .. " " .. line
    if line:find("%]") then
      for m in collecting.buf:gmatch('"([^"]+)"') do
        collecting.into[#collecting.into + 1] = m
      end
      collecting = nil
    end
    return ""
  end
  for line in (text .. "\n"):gmatch("(.-)\n") do
    line = finish_array(line)
    local header = line:match("^%s*%[+([^%]]+)%]+%s*$")
    if header then
      section = header
      if header == "bin" then bins[#bins + 1] = {} end
    elseif collecting == nil then
      local key, val = line:match('^%s*([%w_-]+)%s*=%s*"(.-)"')
      if key == "name" and section == "package" then pkg = val end
      if section == "bin" and bins[#bins] then
        if key == "name" then bins[#bins].name = val end
        if key == "path" then bins[#bins].path = val end
      end
      if section == "workspace" and line:match("^%s*members%s*=") then
        collecting = { buf = line, into = members }
        finish_array("")
      end
    end
  end
  return pkg, bins, members
end

local function add_bin(list, seen, name)
  if not name or name == "" or seen[name] then return end
  seen[name] = true
  list[#list + 1] = name
end

--- Runnable bin names for a package manifest. Nil when this is not a package root.
function M.bins(root)
  local text = read_file(root .. "/Cargo.toml")
  if not text then return nil end
  local pkg, declared, members = scan_manifest(text)
  local names, seen = {}, {}
  for _, bin in ipairs(declared) do
    add_bin(names, seen, bin.name)
  end
  if pkg and vim.fn.filereadable(root .. "/src/main.rs") == 1 then
    local claimed = false
    for _, bin in ipairs(declared) do
      if bin.path and bin.path:find("src/main.rs", 1, true) then claimed = true end
    end
    if not claimed then add_bin(names, seen, pkg) end
  end
  local extra = vim.fn.glob(root .. "/src/bin/*.rs", false, true)
  for _, path in ipairs(extra) do
    add_bin(names, seen, vim.fn.fnamemodify(path, ":t:r"))
  end
  if #names > 0 then return names end
  local all = {}
  for _, member in ipairs(members) do
    local pattern = member:find("[*?]") and member or nil
    local dirs = pattern and vim.fn.glob(root .. "/" .. pattern, false, true) or { root .. "/" .. member }
    for _, dir in ipairs(dirs) do
      if vim.fn.isdirectory(dir) == 1 then
        for _, name in ipairs(M.bins(dir) or {}) do
          add_bin(all, seen, name)
        end
      end
    end
  end
  return all
end

function M.is_server(root)
  return #(M.bins(root) or {}) > 0
end

local function cargo_field(args, flag)
  for i, a in ipairs(args) do
    if a == flag then return args[i + 1] end
  end
end

local function parse_env(text)
  local env = {}
  if not text then return env end
  for line in (text .. "\n"):gmatch("(.-)\n") do
    line = line:gsub("%s+#.*$", "")
    local key, val = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key then
      val = val:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
      env[key] = val
    end
  end
  return env
end

local function load_env(root, profile)
  local env = {}
  local files = { ".env", ".env.local" }
  if profile == "prod" then
    vim.list_extend(files, { ".env.production", ".env.prod" })
  else
    vim.list_extend(files, { ".env.development", ".env.dev" })
  end
  for _, name in ipairs(files) do
    env = vim.tbl_extend("force", env, parse_env(read_file(root .. "/" .. name)))
  end
  return env
end

local function launch_configs(root, fallback)
  local raw = read_file(root .. "/.vscode/launch.json")
  if not raw then return {} end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" or type(decoded.configurations) ~= "table" then
    return {}
  end
  local configs = {}
  for _, cfg in ipairs(decoded.configurations) do
    local rust = cfg.cargo or cfg.type == "lldb" or cfg.type == "codelldb"
    if rust and (not cfg.request or cfg.request == "launch") then
      local args = (cfg.cargo and cfg.cargo.args) or {}
      configs[#configs + 1] = {
        name = cfg.name,
        kind = "rust",
        bin = cargo_field(args, "--bin") or fallback,
        release = vim.tbl_contains(args, "--release"),
        env = cfg.env or {},
      }
    end
  end
  return configs
end

--- Launch configs: .vscode/launch.json when present, otherwise Dev/Prod per bin.
function M.configs(root)
  local bins = M.bins(root) or {}
  local from_file = launch_configs(root, bins[1])
  if #from_file > 0 then return from_file end
  local configs = {}
  for _, name in ipairs(bins) do
    local label = #bins == 1 and "" or (name .. " ")
    configs[#configs + 1] = {
      name = label .. "Dev",
      kind = "rust",
      bin = name,
      release = false,
      env = load_env(root, "dev"),
    }
    configs[#configs + 1] = {
      name = label .. "Prod",
      kind = "rust",
      bin = name,
      release = true,
      env = load_env(root, "prod"),
    }
  end
  return configs
end

function M.is_running()
  if M.running then return true end
  local ok, dap = pcall(require, "dap")
  return ok and dap.session() ~= nil
end

local function append(text)
  if text == nil or text == "" then return end
  vim.schedule(function()
    local bufnr = vim.fn.bufnr(LOG)
    if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then return end
    local lines = vim.split(text:gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
    vim.bo[bufnr].modifiable = true
    local last = vim.api.nvim_buf_line_count(bufnr)
    local cur = vim.api.nvim_buf_get_lines(bufnr, last - 1, last, false)[1] or ""
    lines[1] = cur .. lines[1]
    vim.api.nvim_buf_set_lines(bufnr, last - 1, last, false, lines)
    vim.bo[bufnr].modifiable = false
    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
      local l = vim.api.nvim_buf_line_count(bufnr)
      pcall(vim.api.nvim_win_set_cursor, win, { l, 0 })
    end
  end)
end

local function open_log()
  local bufnr = vim.fn.bufnr(LOG)
  if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, LOG)
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].filetype = "log"
  end
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.bo[bufnr].modifiable = false
  local visible = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then visible = true end
  end
  if not visible then
    vim.cmd("botright 15split")
    vim.api.nvim_win_set_buf(0, bufnr)
    vim.cmd("wincmd p")
  end
  local ok, baleia = pcall(require, "baleia")
  if ok then baleia.setup({}).automatically(bufnr) end
  return bufnr
end

function M.toggle_log()
  local bufnr = vim.fn.bufnr(LOG)
  if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return vim.notify("No Rust log yet (run the project first)", vim.log.levels.INFO)
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

local function merged_env(extra)
  local env = vim.fn.environ()
  for k, v in pairs(extra or {}) do
    env[k] = v
  end
  return env
end

local function listen_port(env)
  env = env or {}
  if env.PORT and tostring(env.PORT):match("^%d+$") then return tostring(env.PORT) end
  for _, key in ipairs({ "GRPC_ADDR", "ADDR", "BIND", "LISTEN" }) do
    local port = env[key] and tostring(env[key]):match(":(%d+)%s*$")
    if port then return port end
  end
end

local function free_port(env)
  local port = listen_port(env)
  if not port then return end
  local out = vim.fn.system({ "lsof", "-nP", "-tiTCP:" .. port, "-sTCP:LISTEN" })
  if vim.v.shell_error ~= 0 or not out or out == "" then return end
  local pids = {}
  for pid in out:gmatch("%d+") do
    pids[#pids + 1] = pid
  end
  if #pids == 0 then return end
  vim.fn.system(vim.list_extend({ "kill", "-9" }, pids))
  append("[killed " .. table.concat(pids, ", ") .. " on :" .. port .. "]\n")
end

local function release_previous(conf)
  free_port(conf and conf.env)
  if M.handle then
    pcall(function() M.handle:kill(9) end)
    M.handle = nil
    M.running = false
  end
end

local function on_exit(out)
  M.running = false
  M.handle = nil
  append("\n[exited " .. tostring(out.code) .. "]\n")
  vim.schedule(function()
    pcall(function() require("runconfig").refresh_burst() end)
  end)
end

function M.stop()
  if M.handle then
    pcall(function() M.handle:kill(15) end)
    local handle = M.handle
    vim.defer_fn(function()
      if M.running and handle then pcall(function() handle:kill(9) end) end
    end, 800)
  end
  local ok, dap = pcall(require, "dap")
  if ok and dap.session() then
    dap.terminate()
    pcall(function() require("dapui").close() end)
  end
  vim.schedule(function() pcall(function() require("runconfig").refresh_burst() end) end)
end

local function cargo_cmd(root, conf, sub)
  local cmd = { "cargo", sub, "--manifest-path", root .. "/Cargo.toml", "--bin", conf.bin }
  if conf.release and sub ~= "build" then table.insert(cmd, "--release") end
  return cmd
end

local function cargo_run(root, conf)
  open_log()
  release_previous(conf)
  local cmd = cargo_cmd(root, conf, "run")
  append(table.concat(cmd, " ") .. "\n")
  M.running = true
  M.handle = vim.system(cmd, {
    cwd = root,
    env = merged_env(conf.env),
    stdout = function(_, data) if data then append(data) end end,
    stderr = function(_, data) if data then append(data) end end,
  }, on_exit)
  vim.schedule(function() pcall(function() require("runconfig").refresh_burst() end) end)
end

local function ensure_adapter()
  local dap = require("dap")
  if dap.adapters.codelldb then return true end
  local ra = vim.g.rustaceanvim
  if ra and ra.dap and ra.dap.adapter then
    dap.adapters.codelldb = ra.dap.adapter
    return true
  end
  local codelldb = vim.fn.exepath("codelldb")
  if codelldb == "" then
    local mason = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
    if vim.fn.executable(mason) == 1 then codelldb = mason end
  end
  if codelldb == "" then return false end
  local ext = (vim.uv.os_uname().sysname == "Linux") and ".so" or ".dylib"
  local lib = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/lldb/lib/liblldb" .. ext
  local ok, cfg = pcall(require, "rustaceanvim.config")
  if not ok then return false end
  dap.adapters.codelldb = cfg.get_codelldb_adapter(codelldb, lib)
  return true
end

local function executable_from(stdout, bin)
  local program
  for line in vim.gsplit(stdout or "", "\n", { plain = true }) do
    local ok, msg = pcall(vim.json.decode, line)
    if ok and type(msg) == "table" and msg.reason == "compiler-artifact" and msg.executable then
      local target = msg.target and msg.target.name
      if not bin or target == bin then program = msg.executable end
    end
  end
  return program
end

local function cargo_debug(root, conf)
  if not ensure_adapter() then
    return vim.notify("codelldb not found (install via Mason)", vim.log.levels.ERROR)
  end
  open_log()
  release_previous(conf)
  local cmd = {
    "cargo", "build", "--manifest-path", root .. "/Cargo.toml",
    "--bin", conf.bin, "--message-format=json",
  }
  append(table.concat(cmd, " ") .. "\n")
  vim.notify("Building " .. conf.bin .. " for debug…")
  vim.system(cmd, {
    cwd = root,
    env = merged_env(conf.env),
    stdout = function(_, data) if data then append(data) end end,
    stderr = function(_, data) if data then append(data) end end,
  }, function(out)
    vim.schedule(function()
      local program = executable_from(out.stdout, conf.bin)
      if out.code ~= 0 or not program then
        append("\n[build failed]\n")
        return vim.notify("Build failed", vim.log.levels.ERROR)
      end
      require("dap").run({
        name = conf.name or conf.bin,
        type = "codelldb",
        request = "launch",
        program = program,
        cwd = root,
        args = {},
        env = conf.env or {},
        stopOnEntry = false,
      })
      pcall(function() require("dapui").open() end)
      pcall(function() require("runconfig").refresh_burst() end)
    end)
  end)
end

function M.run(root, conf, force_debug)
  conf = conf or M.configs(root)[1]
  if not conf or not conf.bin then
    return vim.notify("No runnable Rust bin in " .. root, vim.log.levels.WARN)
  end
  if force_debug then
    cargo_debug(root, conf)
  else
    cargo_run(root, conf)
  end
end

return M
