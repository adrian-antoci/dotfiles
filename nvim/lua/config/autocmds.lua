-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local side = require("config.side_panels")

side.setup_autocmds()

-- Startup layout (same path as <leader>fp project open); restores last panel widths
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    vim.schedule(function()
      if vim.fn.argc(-1) > 0 then
        local arg = vim.fn.argv(0)
        if type(arg) == "string" and arg:match("COMMIT_EDITMSG") then
          return
        end
      end
      side.startup_layout()
    end)
  end,
})
