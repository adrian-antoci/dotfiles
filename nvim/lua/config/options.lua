-- Enable exrc so .nvim.lua is loaded for flutter-tools project config
vim.o.exrc = true

-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- No swap files; always trust the on-disk version
vim.opt.swapfile = false
vim.opt.autoread = true

-- Use neo-tree as the file explorer (disables the snacks explorer)
vim.g.lazyvim_explorer = "neo-tree"

-- Melos monorepo: resolve the repo root (.git) instead of the per-package
-- pubspec.yaml that dartls reports as its LSP root. Without this, root-scoped
-- pickers (Grep/Find Files with <leader>/, <leader>sg, <leader>ff) only search
-- the current package, so files in other packages (e.g. vulcan_translations)
-- never show up. This only affects LazyVim's root detection, not the LSP.
vim.g.root_spec = { { ".git" }, "cwd" }
