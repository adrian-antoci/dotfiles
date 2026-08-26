return {
  -- Use neo-tree as the file explorer (replaces snacks explorer for <leader>e).
  -- LazyVim's extra rebinds <leader>e / <leader>fe to neo-tree automatically.
  { import = "lazyvim.plugins.extras.editor.neo-tree" },

  -- Disable the old snacks explorer so neo-tree is the only file browser.
  { "folke/snacks.nvim", opts = { explorer = { enabled = false } } },

  {
    "nvim-neo-tree/neo-tree.nvim",
    -- Adds the `diagnostics` source (all files that have LSP diagnostics/issues).
    dependencies = { "mrbjarksen/neo-tree-diagnostics.nvim" },
    opts = function(_, opts)
      -- The `diagnostics` source lists everything from `vim.diagnostic.get()`,
      -- which for the Dart LSP includes TODO/FIXME comments (code = "todo",
      -- severity = INFO). We only want real problems in the "Issues" tab, so we
      -- wrap the source's collector to drop TODO/FIXME while it gathers items.
      -- This runs when neo-tree loads (plugin is on the runtimepath) and is
      -- scoped to the Issues tab only: inline diagnostics, Trouble and
      -- `<leader>xx` still show TODO/FIXME.
      local ok, items = pcall(require, "neo-tree.sources.diagnostics.lib.items")
      if ok and not items._todo_filter_wrapped then
        local orig_get = items.get_diagnostics
        items.get_diagnostics = function(...)
          local real_get = vim.diagnostic.get
          vim.diagnostic.get = function(bufnr, get_opts)
            return vim.tbl_filter(function(d)
              local code = d.code and tostring(d.code):lower() or nil
              return code ~= "todo" and code ~= "fixme"
            end, real_get(bufnr, get_opts))
          end
          local result = { pcall(orig_get, ...) }
          vim.diagnostic.get = real_get
          if not result[1] then
            error(result[2])
          end
          return unpack(result, 2)
        end
        items._todo_filter_wrapped = true
      end

      -- Explorer, uncommitted (git status) and files with issues (diagnostics).
      opts.sources = { "filesystem", "git_status", "diagnostics" }
      opts.window = vim.tbl_deep_extend("force", opts.window or {}, {
        position = "left",
      })
      -- Tab bar shown as a winbar at the top of the sidebar window.
      opts.source_selector = {
        winbar = true,
        statusline = false,
        content_layout = "center",
        sources = {
          { source = "filesystem", display_name = "󰉓 Explorer" },
          { source = "git_status", display_name = "󰊢 Uncommitted" },
          { source = "diagnostics", display_name = "󰃤 Issues" },
        },
      }
      return opts
    end,
  },
}
