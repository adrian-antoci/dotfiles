-- List Flutter run targets (connected devices + available emulators) the way
-- Android Studio's device dropdown does, and boot an emulator on demand. Uses
-- flutter-tools' executable resolver so fvm-managed SDKs work transparently.

local M = {}

---@alias RunTarget {id: string, name: string, platform: string, is_emulator: boolean, emulator_id: string?, running: boolean, wireless: boolean}

-- Cached run targets from the last successful fetch, so the picker can show
-- devices instantly instead of blocking on `flutter devices` every time.
---@type RunTarget[]
M.cache = {}

-- Change listeners, notified whenever the cached target set actually changes.
---@type table<integer, fun(targets: RunTarget[])>
local listeners = {}
local next_listener_id = 0
local last_fingerprint = nil

-- Background poll timer + refcount, shared by all open watchers.
local watch_timer = nil
local watch_count = 0

---Resolve the (fvm-aware) flutter binary, then invoke `cb(bin)`.
local function flutter_bin(cb)
  require("flutter-tools.executable").flutter(cb)
end

---Infer whether a connected device is on a wireless connection from its id.
---flutter devices --machine exposes no transport field, but Android wireless
---(adb over tcp/ip) serials look like `192.168.1.42:5555` and wireless iOS ids
---contain a `-` separated network suffix; a plain IPv4[:port] id means wireless.
---@param id string?
---@return boolean
local function is_wireless(id)
  if type(id) ~= "string" then return false end
  return id:match("^%d+%.%d+%.%d+%.%d+:%d+$") ~= nil
    or id:match("^%d+%.%d+%.%d+%.%d+$") ~= nil
end

---Parse `flutter devices --machine` JSON into RunTargets.
---@param stdout string
---@return RunTarget[]
local function parse_connected(stdout)
  local out = {}
  local ok, parsed = pcall(vim.json.decode, stdout or "")
  if ok and type(parsed) == "table" then
    for _, d in ipairs(parsed) do
      out[#out + 1] = {
        id = d.id,
        name = d.name,
        platform = d.targetPlatform or "",
        is_emulator = d.emulator == true,
        emulator_id = d.emulatorId,
        running = true,
        wireless = not (d.emulator == true) and is_wireless(d.id),
      }
    end
  end
  return out
end

---Parse `flutter emulators` text output (`id • name • manufacturer • platform`).
---@param stdout string
---@return RunTarget[]
local function parse_emulators(stdout)
  local out = {}
  for line in (stdout or ""):gmatch("[^\n]+") do
    local parts = vim.split(line, "•")
    if #parts >= 2 and not line:find("flutter emulators") then
      local id, name = vim.trim(parts[1]), vim.trim(parts[2])
      if id ~= "" and name ~= "" and not line:lower():find("available emulator") then
        out[#out + 1] = {
          id = id,
          name = name,
          platform = vim.trim(parts[4] or ""),
          is_emulator = true,
          emulator_id = id,
          running = false,
          wireless = false,
        }
      end
    end
  end
  return out
end

---Fetch all run targets, connected devices first, then not-running emulators
---(emulators already booted are only shown once, as the connected device).
---@param cb fun(targets: RunTarget[])
local function fetch(cb)
  flutter_bin(function(bin)
    local connected, emulators, pending = {}, {}, 2
    local function finish()
      pending = pending - 1
      if pending > 0 then return end
      local running = {}
      for _, d in ipairs(connected) do
        if d.emulator_id then running[d.emulator_id] = true end
      end
      local out = vim.list_extend({}, connected)
      for _, e in ipairs(emulators) do
        if not running[e.id] then out[#out + 1] = e end
      end
      vim.schedule(function() cb(out) end)
    end
    vim.system({ bin, "devices", "--machine" }, { text = true }, function(res)
      connected = parse_connected(res.stdout)
      finish()
    end)
    vim.system({ bin, "emulators" }, { text = true }, function(res)
      emulators = parse_emulators(res.stdout)
      finish()
    end)
  end)
end

---Stable signature of a target set, used to detect real changes.
---@param targets RunTarget[]
---@return string
local function fingerprint(targets)
  local parts = {}
  for _, t in ipairs(targets) do
    parts[#parts + 1] = (t.id or "") .. ":" .. (t.running and "1" or "0")
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

---Store the freshest targets and, if the set actually changed, notify listeners.
---@param targets RunTarget[]
local function update_cache(targets)
  M.cache = targets
  local fp = fingerprint(targets)
  if fp == last_fingerprint then return end
  last_fingerprint = fp
  for _, cb in pairs(listeners) do
    pcall(cb, targets)
  end
end

---The last-known run targets (may be empty if nothing has been fetched yet).
---@return RunTarget[]
function M.cached()
  return M.cache
end

---Fetch fresh targets, refresh the cache (notifying listeners on change), then
---hand the result to `cb`.
---@param cb fun(targets: RunTarget[])
function M.list(cb)
  fetch(function(targets)
    update_cache(targets)
    cb(targets)
  end)
end

---Register a listener fired whenever the cached target set changes. Returns an
---unsubscribe function.
---@param cb fun(targets: RunTarget[])
---@return fun()
function M.subscribe(cb)
  next_listener_id = next_listener_id + 1
  local id = next_listener_id
  listeners[id] = cb
  return function() listeners[id] = nil end
end

---Poll devices in the background so the cache (and any subscribed pickers) stay
---in sync with connect/disconnect events. Refcounted; returns a stop function
---that must be called once per start.
---@param interval_ms integer?
---@return fun()
function M.start_watch(interval_ms)
  local interval = interval_ms or 2500
  watch_count = watch_count + 1
  if not watch_timer then
    watch_timer = assert(vim.uv.new_timer())
    watch_timer:start(interval, interval, function()
      vim.schedule(function() fetch(update_cache) end)
    end)
  end
  local stopped = false
  return function()
    if stopped then return end
    stopped = true
    watch_count = watch_count - 1
    if watch_count <= 0 and watch_timer then
      watch_timer:stop()
      watch_timer:close()
      watch_timer = nil
      watch_count = 0
    end
  end
end

---Boot an emulator and poll until a matching device appears, then hand back its
---device id (or nil on timeout). Lets `run` target an emulator that isn't up yet.
---@param target RunTarget
---@param cb fun(device_id: string?)
function M.launch_and_wait(target, cb)
  flutter_bin(function(bin)
    vim.system({ bin, "emulators", "--launch", target.emulator_id or target.id }, { text = true })
    local tries = 0
    local timer = assert(vim.uv.new_timer())
    timer:start(2000, 2000, function()
      tries = tries + 1
      vim.system({ bin, "devices", "--machine" }, { text = true }, function(res)
        local id
        for _, d in ipairs(parse_connected(res.stdout)) do
          if (d.emulator_id and d.emulator_id == target.emulator_id) or d.name == target.name then
            id = d.id
            break
          end
        end
        if id then
          timer:stop()
          timer:close()
          vim.schedule(function() cb(id) end)
        elseif tries >= 30 then
          timer:stop()
          timer:close()
          vim.schedule(function() cb(nil) end)
        end
      end)
    end)
  end)
end

return M
