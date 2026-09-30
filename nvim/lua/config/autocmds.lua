-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Warm up the Dart Analysis Server (dartls) on project open, Android-Studio
-- style: start indexing as soon as you open a Flutter/Dart project instead of
-- waiting for the first .dart buffer (which otherwise blocks the first
-- go-to-definition while the whole Melos monorepo is analysed).
--
-- flutter-tools starts dartls lazily via ftplugin/dart -> lsp.attach(), which
-- reads the *current* buffer. So we find one real .dart file, load it into a
-- hidden/unlisted buffer, make it current just long enough to call attach()
-- (dartls' root_dir resolves to the pub-workspace/.git root), then restore the
-- previous buffer. Nothing visible changes; indexing runs in the background.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("dartls_warmup", { clear = true }),
  callback = function()
    vim.schedule(function()
      -- Only warm up when nvim was opened on a directory / with no real file
      -- (opening a .dart file already triggers attach via ftplugin).
      local cur = vim.api.nvim_get_current_buf()
      local cur_name = vim.api.nvim_buf_get_name(cur)
      local cur_ft = vim.bo[cur].filetype
      if cur_ft == "dart" then
        return
      end

      -- Detect a Dart/Flutter project by finding pubspec.yaml upward from cwd.
      local cwd = vim.fn.getcwd()
      local pubspec = vim.fs.find("pubspec.yaml", { path = cwd, upward = true })[1]
      if not pubspec then
        return
      end
      local project_root = vim.fs.dirname(pubspec)

      -- If dartls is already running for this project, do nothing.
      for _, client in ipairs(vim.lsp.get_clients({ name = "dartls" })) do
        if client.config.root_dir and cwd:sub(1, #client.config.root_dir) == client.config.root_dir then
          return
        end
      end

      -- Find a .dart file to attach to: prefer lib/main.dart, then any .dart.
      local dart_file = vim.fs.find("main.dart", { path = project_root, type = "file" })[1]
      if not dart_file then
        dart_file = vim.fs.find(function(name)
          return name:match("%.dart$") ~= nil
        end, { path = project_root, type = "file", limit = 1 })[1]
      end
      if not dart_file then
        return
      end

      -- Load the file as a hidden, unlisted buffer and attach without disturbing
      -- the current window/view.
      local warm_buf = vim.fn.bufadd(dart_file)
      vim.fn.bufload(warm_buf)
      vim.bo[warm_buf].buflisted = false

      local ok, ft_lsp = pcall(require, "flutter-tools.lsp")
      if not ok then
        return
      end

      -- attach() reads the current buffer, so switch to warm_buf briefly.
      local prev_buf = vim.api.nvim_get_current_buf()
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, warm_buf)
      pcall(ft_lsp.attach)
      -- Restore the original buffer (bufadd/bufload keeps warm_buf alive so the
      -- LSP client stays attached to it in the background).
      if vim.api.nvim_buf_is_valid(prev_buf) then
        vim.api.nvim_win_set_buf(win, prev_buf)
      end
      _ = cur_name
    end)
  end,
})

-- Built-in LSP document color support (Neovim 0.12+)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    vim.lsp.document_color.enable(true, { bufnr = ev.buf })
  end,
})

-- Auto-reload buffers when changed externally (e.g. by Claude Code)
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "BufEnter" }, {
  pattern = "*",
  command = "checktime",
})

-- Auto-save when leaving insert mode (no formatting — that runs on save via conform/LSP)
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" and not vim.bo.readonly then
      vim.cmd("silent! write")
    end
  end,
})

-- Restart the LSP whenever the neo-tree "Issues" (diagnostics) tab is opened,
-- so the list of files with issues is refreshed. Only fires when actually
-- switching into the diagnostics source, not on every focus of the sidebar.
local last_neo_tree_source
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("neotree_issues_lsp_restart", { clear = true }),
  callback = function(ev)
    if vim.bo[ev.buf].filetype ~= "neo-tree" then
      return
    end
    local ok, source = pcall(vim.api.nvim_buf_get_var, ev.buf, "neo_tree_source")
    if not ok then
      return
    end
    if source == "diagnostics" and last_neo_tree_source ~= "diagnostics" then
      -- Native `:lsp restart` (Nvim 0.11+). Uses the lowercase form because the
      -- capitalised `:Lsp restart` is ambiguous via vim.cmd() alongside the
      -- `Lsp*` user commands (LspRestart/LspInfo/...) from nvim-lspconfig.
      pcall(vim.cmd, "lsp restart")
    end
    last_neo_tree_source = source
  end,
})

-- Refresh the neo-tree "Issues" tab whenever LSP diagnostics change.
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  group = vim.api.nvim_create_augroup("neotree_issues_refresh", { clear = true }),
  callback = function()
    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "neo-tree" then
          local ok, source = pcall(vim.api.nvim_buf_get_var, buf, "neo_tree_source")
          if ok and source == "diagnostics" then
            pcall(vim.api.nvim_buf_call, buf, function()
              require("neo-tree").refresh(buf)
            end)
          end
        end
      end
    end)
  end,
})
