-- Snacks.picker-backed dropdowns for the run config and device selectors
-- (LazyVim v8 ships Snacks.picker, not Telescope). Each picker is a fuzzy list
-- that only reports the chosen item; running is a separate action.

local M = {}

---@generic T
---@param items T[]
---@param opts snacks.picker.ui_select.Opts
---@param cb fun(choice: T)
local function select(items, opts, cb)
  require("snacks.picker").select(items, opts, function(choice)
    if choice then cb(choice) end
  end)
end

---Pick a run configuration (parsed from .vscode/launch.json).
---@param configs table[]
---@param cb fun(config: table)
function M.pick_config(configs, cb)
  select(configs, {
    prompt = "Run configuration",
    format_item = function(c)
      return "\u{f135}  " .. (c.name or "?")
    end,
  }, cb)
end

---Pick a device / emulator. Returns the underlying Snacks picker so callers can
---live-update it (mutate `targets` in place, then `picker:find({refresh=true})`).
---`on_choice` receives the chosen target, or nil when the picker is dismissed.
---@param targets table[]
---@param on_choice fun(target: table?)
---@return snacks.Picker
function M.pick_device(targets, on_choice)
  return require("snacks.picker").select(targets, {
    prompt = "Select device",
    format_item = function(d)
      local icon = d.is_emulator and "\u{f11b}" or "\u{f109}"
      local platform = d.platform ~= "" and ("  \u{2022} " .. d.platform) or ""
      -- Connection indicator for physical, running devices (Android-Studio-style):
      -- wifi glyph for wireless (adb/network id), USB glyph for cable. Emulators
      -- and not-running targets get no connection marker.
      local conn = ""
      if not d.is_emulator and d.running then
        conn = d.wireless and "  \u{f1eb}" or "  \u{f287}"
      end
      local tag = d.running and "" or "  (not running)"
      return icon .. "  " .. d.name .. platform .. conn .. tag
    end,
    -- Keep the picker open when the (cached) device list is empty so the live
    -- fetch can populate it; otherwise Snacks warns "No results found" and
    -- closes immediately on the first open before devices have loaded.
    snacks = { show_empty = true },
  }, function(choice) on_choice(choice) end)
end

---Pick a Flutter dev-tools action (each item has an icon, label and `run`).
---@param items { icon: string, label: string, run: fun() }[]
function M.pick_dev_tool(items)
  select(items, {
    prompt = "Flutter dev tools",
    format_item = function(i)
      return i.icon .. "  " .. i.label
    end,
  }, function(choice)
    choice.run()
  end)
end

return M
