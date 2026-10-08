-- Read workspace .vscode/launch.json and Android Studio's shared Flutter run
-- configurations, translating both into flutter.ProjectConfig entries.
--
-- flutter-tools then prompts you to pick one on :FlutterRun (its run-config
-- dropdown), and surfaces the selected name via the `project_config`
-- statusline decoration (rendered in lualine).

local M = {}

-- Strip // line comments and /* */ block comments so `vim.json.decode` can
-- parse VS Code's jsonc. Naive but sufficient for launch.json (no comment-like
-- sequences appear inside its string values).
local function strip_jsonc(text)
  text = text:gsub("/%*.-%*/", "")
  local out = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    -- Drop a // comment only when it's not inside a string. Good enough here:
    -- launch.json values don't contain "//".
    if not line:find('"[^"]*//', 1) then
      line = line:gsub("//.*$", "")
    end
    out[#out + 1] = line
  end
  return table.concat(out, "\n")
end

-- Extract the value of `--flag=value` or `--flag value` from an args list.
local function arg_value(args, flag)
  -- Escape Lua pattern magic chars (notably `-`) so the flag matches literally.
  local pattern = "^" .. flag:gsub("([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1") .. "=(.+)$"
  for i, a in ipairs(args) do
    local eq = a:match(pattern)
    if eq then return eq end
    if a == flag then return args[i + 1] end
  end
  return nil
end

-- Args we already map to dedicated ProjectConfig keys; everything else is
-- forwarded verbatim as `additional_args`.
local function passthrough_args(args)
  local skip_next, out = false, {}
  for _, a in ipairs(args) do
    if skip_next then
      skip_next = false
    elseif a == "--flavor" then
      skip_next = true
    elseif a:match("^%-%-flavor=") or a:match("^%-%-dart%-define%-from%-file=") then
      -- handled separately
    elseif a == "--dart-define-from-file" then
      skip_next = true
    else
      out[#out + 1] = a
    end
  end
  return out
end

-- Join two path segments with a single separator.
local function join(a, b)
  if a:sub(-1) == "/" then return a .. b end
  return a .. "/" .. b
end

-- Resolve `p` to an absolute path. Relative paths are anchored to `base`
-- (never to nvim's cwd), so run configs work regardless of where nvim was
-- launched from. This is the fix for flutter-tools resolving a relative cwd
-- against the wrong directory and falling back to the workspace root.
local function absolutise(p, base)
  if p == nil or p == "" then return p end
  if p:match("^/") or p:match("^%a:[/\\]") then return p end
  return join(base, p)
end

---Convert a single launch.json configuration into a flutter.ProjectConfig.
---Returns nil for non-`launch` requests (e.g. attach).
---@param root string absolute workspace root, used to anchor relative paths
local function to_project_config(cfg, root)
  if cfg.request and cfg.request ~= "launch" then return nil end
  local args = cfg.args or {}
  -- cwd in launch.json is relative to the workspace root; make it absolute.
  local cwd = absolutise(cfg.cwd, root)
  -- program (target) is relative to the config's cwd; make it absolute too so
  -- `--target` is unambiguous no matter which directory flutter runs from.
  local target = cfg.program
  if target and cwd then target = absolutise(target, cwd) end
  local project = {
    name = cfg.name,
    target = target,
    cwd = cwd,
    flavor = arg_value(args, "--flavor"),
    dart_define_from_file = arg_value(args, "--dart-define-from-file"),
  }
  -- flutterMode may be a VS Code ${input:...} placeholder; only pass concrete
  -- values so flutter-tools defaults to debug otherwise.
  local mode = cfg.flutterMode
  if mode == "debug" or mode == "profile" or mode == "release" then
    project.flutter_mode = mode
  end
  local extra = passthrough_args(args)
  if #extra > 0 then project.additional_args = extra end
  return project
end

-- Walk up from `start` looking for a directory with run configurations.
-- Makes detection independent of nvim's launch dir.
local function find_launch_root(start)
  local dir = start
  for _ = 1, 30 do
    if vim.uv.fs_stat(join(dir, ".vscode/launch.json"))
      or vim.uv.fs_stat(join(dir, ".idea/runConfigurations")) then return dir end
    local parent = dir:match("^(.*)/[^/]+$")
    if not parent or parent == "" or parent == dir then break end
    dir = parent
  end
  return nil
end

-- Public alias so other runconfig modules resolve the same workspace root.
M.find_root = find_launch_root

-- Android Studio stores shared Flutter configurations in individual XML files.
-- Only read the few attributes needed for flutter run; do not load local IDE
-- workspace state or unrelated test/Melos configurations.
local function xml_attr(tag, key)
  local value = tag:match("%s" .. key .. '%s*=%s*"([^"]*)"')
  if not value then return nil end
  local entities = { amp = "&", quot = '"', apos = "'", lt = "<", gt = ">" }
  return (value:gsub("&([^;]+);", function(entity) return entities[entity] or "&" .. entity .. ";" end))
end

local function parse_idea(root)
  local configs = {}
  local files = vim.fn.glob(join(root, ".idea/runConfigurations/*.xml"), false, true)
  table.sort(files)
  for _, file in ipairs(files) do
    local fd = io.open(file, "r")
    if fd then
      local xml = fd:read("*a")
      fd:close()
      local tag, body = xml:match("(<configuration%s[^>]*>)(.-)</configuration>")
      if tag and xml_attr(tag, "type") == "FlutterRunConfigurationType" then
        local options = {}
        for option in body:gmatch("<option%s[^>]*>") do
          local name = xml_attr(option, "name")
          if name then options[name] = xml_attr(option, "value") end
        end
        local target = options.filePath
        local prefix = "$PROJECT_DIR$/"
        if target and target:sub(1, #prefix) == prefix then
          target = join(root, target:sub(#prefix + 1))
        end
        -- Skip unresolved IDE variables; flutter-tools needs a real target.
        if target and not target:find("$", 1, true) then
          target = absolutise(target, root)
          local pubspec = vim.fs.find("pubspec.yaml", { path = vim.fs.dirname(target), upward = true, stop = root })[1]
          local name = xml_attr(tag, "name")
          if pubspec and name then
            local args = vim.split(options.additionalArgs or "", "%s+", { trimempty = true })
            local project = {
              name = name,
              target = target,
              cwd = vim.fs.dirname(pubspec),
              flavor = options.buildFlavor,
              device = options.deviceId,
              dart_define_from_file = arg_value(args, "--dart-define-from-file"),
            }
            local extra = passthrough_args(args)
            if #extra > 0 then project.additional_args = extra end
            configs[#configs + 1] = project
          end
        end
      end
    end
  end
  return configs
end

---Parse both workspace run-configuration sources into flutter.ProjectConfig entries.
---@param root string|nil workspace root; when omitted, searched for upward
---  from the current buffer's directory (falling back to nvim's cwd).
---@return table[] configs (possibly empty)
function M.parse(root)
  if not root then
    local buf = vim.api.nvim_buf_get_name(0)
    local start = (buf ~= "" and vim.fs and vim.fs.dirname(buf)) or vim.uv.cwd()
    root = find_launch_root(start) or find_launch_root(vim.uv.cwd()) or vim.uv.cwd()
  end
  local path = root .. "/.vscode/launch.json"
  local fd = io.open(path, "r")
  local configs = {}
  local seen = {}
  if fd then
    local raw = fd:read("*a")
    fd:close()
    local ok, decoded = pcall(vim.json.decode, strip_jsonc(raw))
    if ok and type(decoded) == "table" and type(decoded.configurations) == "table" then
      for _, cfg in ipairs(decoded.configurations) do
        local project = to_project_config(cfg, root)
        if project and project.name then
          configs[#configs + 1] = project
          seen[project.name] = true
        end
      end
    end
  end
  for _, project in ipairs(parse_idea(root)) do
    if not seen[project.name] then
      configs[#configs + 1] = project
      seen[project.name] = true
    end
  end
  return configs
end

return M
