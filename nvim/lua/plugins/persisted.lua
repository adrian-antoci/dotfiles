return {
  "folke/persistence.nvim",
  event = "BufReadPost",
  config = function()
    require("persistence").setup({
      dir = vim.fn.stdpath("data") .. "/sessions",
      auto_restore = true,
      auto_save = true,
    })
  end,
}
