-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local side = require("config.side_panels")

-- Startup layout
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
      side.ensure()
    end)
  end,
})

-- After <leader>fp session restore (or :SessionLoad)
vim.api.nvim_create_autocmd("SessionLoadPost", {
  callback = function()
    side.ensure({ force = true })
  end,
})

-- When project cwd changes without a session (fp fallback / :cd / :tcd)
vim.api.nvim_create_autocmd("DirChanged", {
  callback = function(ev)
    -- only global/tab cwd changes (project switches), not window-local
    if ev.scope ~= "global" and ev.scope ~= "tabpage" then
      return
    end
    -- skip noisy intermediate changes during startup
    if vim.g.side_panels_ready then
      side.ensure({ force = true })
    end
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    vim.defer_fn(function()
      vim.g.side_panels_ready = true
    end, 500)
  end,
})
