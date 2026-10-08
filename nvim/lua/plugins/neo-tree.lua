return {
  -- Use neo-tree as the file explorer (replaces snacks explorer for <leader>e).
  -- LazyVim's extra rebinds <leader>e / <leader>fe to neo-tree automatically.
  { import = "lazyvim.plugins.extras.editor.neo-tree" },

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

      -- Android Studio-style project view: thin chevrons, no tree lines, one
      -- folder glyph tinted by role (source / test / excluded), file names
      -- coloured by VCS status with no status symbols, no extra columns.
      local folder = "\u{f413}"
      local special_folders = {
        lib = "NeoTreeDirectoryIconSource",
        test = "NeoTreeDirectoryIconTest",
        integration_test = "NeoTreeDirectoryIconTest",
        test_driver = "NeoTreeDirectoryIconTest",
        build = "NeoTreeDirectoryIconExcluded",
        [".dart_tool"] = "NeoTreeDirectoryIconExcluded",
        [".idea"] = "NeoTreeDirectoryIconExcluded",
      }
      local default_provider = require("neo-tree.defaults").default_component_configs.icon.provider
      opts.default_component_configs = vim.tbl_deep_extend("force", opts.default_component_configs or {}, {
        indent = {
          indent_size = 2,
          padding = 1,
          with_markers = false,
          with_expanders = true,
          expander_collapsed = "\u{f460}",
          expander_expanded = "\u{f47c}",
          expander_highlight = "NeoTreeExpander",
        },
        icon = {
          folder_closed = folder,
          folder_open = folder,
          folder_empty = folder,
          folder_empty_open = folder,
          provider = function(icon, node, state)
            default_provider(icon, node, state)
            if node.type == "directory" then
              icon.highlight = special_folders[node.name] or "NeoTreeDirectoryIcon"
            end
          end,
        },
        name = { use_git_status_colors = true },
        git_status = {
          symbols = {
            added = "",
            deleted = "",
            modified = "",
            renamed = "",
            untracked = "",
            ignored = "",
            unstaged = "",
            staged = "",
            conflict = "",
          },
        },
        file_size = { enabled = false },
        type = { enabled = false },
        last_modified = { enabled = false },
        created = { enabled = false },
      })
      opts.filesystem = vim.tbl_deep_extend("force", opts.filesystem or {}, {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = { ".git", ".DS_Store" },
        },
      })
      return opts
    end,
  },
}
