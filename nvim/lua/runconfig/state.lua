-- Per-project persistence for the selected run config + device, so the choices
-- survive across Neovim sessions the way Android Studio remembers them. Stored
-- as a single JSON map keyed by workspace root under stdpath("data").

local M = {}

local file = vim.fn.stdpath("data") .. "/runconfig/selections.json"

---Read the whole selections map from disk (empty table if missing/corrupt).
---@return table<string, table>
local function read_all()
  local fd = io.open(file, "r")
  if not fd then return {} end
  local raw = fd:read("*a")
  fd:close()
  local ok, data = pcall(vim.json.decode, raw)
  if ok and type(data) == "table" then return data end
  return {}
end

---Load the persisted selection for a workspace root.
---@param root string
---@return { config: string?, device: table? }
function M.load(root)
  return read_all()[root] or {}
end

---Persist the selection for a workspace root.
---@param root string
---@param selection { config: string?, device: table? }
function M.save(root, selection)
  local all = read_all()
  all[root] = selection
  vim.fn.mkdir(vim.fn.fnamemodify(file, ":h"), "p")
  local fd = io.open(file, "w")
  if not fd then return end
  fd:write(vim.json.encode(all))
  fd:close()
end

return M
