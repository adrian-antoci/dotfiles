-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

vim.keymap.set({ "n", "t" }, "<leader>tf", function()
  local explorer = Snacks.picker.get({ source = "explorer" })[1]
  local cwd = (explorer and explorer:cwd()) or LazyVim.root()
  Snacks.terminal(nil, {
    cwd = cwd,
    win = {
      position = "float",
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
  })
end, { desc = "Floating Terminal (Explorer Root)" })
