-- Tracks whether the Dart analysis server (dartls) is busy analysing, so the
-- toolbar can show it (LSP requests like references are slow until it's idle).
-- dartls reports analysis as a `$/progress` task with the token "ANALYZING".
-- flutter-tools drops progress messages while in insert mode, but always emits
-- FlutterToolsLspAnalysisCompleted on completion, so that is used as the end
-- signal too to avoid a stuck indicator.
--
-- Warm-up: dartls builds its references index lazily, per file, on the first
-- search that touches it. Once a client's first analysis finishes, one
-- background references request for a name nearly every file uses forces most
-- of the workspace to be indexed, so the first real `gr` reuses that index.
-- The toolbar's "Analyzing…" segment stays on while the warm-up runs.

local M = {}

local ANALYZING_TOKEN = "ANALYZING"
local WARMUP_NAMES = { "BuildContext", "Widget" }

---@type table<integer, true> dartls client ids currently analysing
local busy = {}
---@type table<integer, true> dartls client ids with a warm-up request in flight
local warming = {}
---@type table<integer, true> dartls client ids that finished a first analysis
local analyzed = {}
---@type table<integer, true> dartls client ids already warmed up (or in flight)
local warmed = {}

---@return boolean
function M.is_analyzing() return next(busy) ~= nil or next(warming) ~= nil end

---@param fn fun()
local function update(fn)
  local was = M.is_analyzing()
  fn()
  if was ~= M.is_analyzing() then require("runconfig").refresh() end
end

---@param client_id integer
---@param analyzing boolean
local function set(client_id, analyzing)
  update(function() busy[client_id] = analyzing or nil end)
end

---@param client_id integer
---@param on boolean
local function set_warming(client_id, on)
  update(function() warming[client_id] = on or nil end)
end

--- First non-comment occurrence of a warm-up name in the buffer.
---@param bufnr integer
---@return integer? row, integer? col, string? text 0-based row and byte col
local function find_symbol(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, name in ipairs(WARMUP_NAMES) do
    local pattern = "%f[%w_]" .. name .. "%f[^%w_]"
    for i, text in ipairs(lines) do
      local col = not text:match("^%s*//") and text:find(pattern)
      if col then return i - 1, col - 1, text end
    end
  end
end

--- Send the one-off background references request for this client, using the
--- first attached buffer that mentions a warm-up name. If none does yet, this
--- is retried when the client attaches to another buffer.
---@param client vim.lsp.Client
local function warm_up(client)
  if warmed[client.id] or not analyzed[client.id] then return end
  for bufnr in pairs(client.attached_buffers) do
    local row, col, text = find_symbol(bufnr)
    if row then
      warmed[client.id] = true
      set_warming(client.id, true)
      client:request("textDocument/references", {
        textDocument = { uri = vim.uri_from_bufnr(bufnr) },
        position = { line = row, character = vim.str_utfindex(text, client.offset_encoding, col) },
        context = { includeDeclaration = false },
      }, function() set_warming(client.id, false) end, bufnr)
      return
    end
  end
end

---@param client vim.lsp.Client
local function on_analysis_end(client)
  set(client.id, false)
  analyzed[client.id] = true
  warm_up(client)
end

local function clear_all()
  for _, client in ipairs(vim.lsp.get_clients({ name = "dartls" })) do
    on_analysis_end(client)
  end
end

function M.setup()
  local grp = vim.api.nvim_create_augroup("runconfig_analysis", { clear = true })
  vim.api.nvim_create_autocmd("LspProgress", {
    group = grp,
    callback = function(ev)
      local data = ev.data or {}
      local params = data.params
      if not (params and params.token == ANALYZING_TOKEN and params.value) then return end
      local client = vim.lsp.get_client_by_id(data.client_id)
      if not (client and client.name == "dartls") then return end
      if params.value.kind == "end" then
        on_analysis_end(client)
      else
        set(client.id, true)
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = grp,
    pattern = "FlutterToolsLspAnalysisCompleted",
    callback = clear_all,
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = grp,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client.name == "dartls" then vim.schedule(function() warm_up(client) end) end
    end,
  })
  vim.api.nvim_create_autocmd("LspDetach", {
    group = grp,
    callback = function(ev)
      local id = ev.data.client_id
      vim.schedule(function()
        local client = vim.lsp.get_client_by_id(id)
        if client and not client:is_stopped() then return end
        set(id, false)
        set_warming(id, false)
      end)
    end,
  })
end

return M
