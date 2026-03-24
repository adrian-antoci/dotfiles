return {
  {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    event = "VeryLazy",
    opts = {},
  },
  {
    "tris203/precognition.nvim",
    event = "VeryLazy",
    opts = {
      startVisible = false,
    },
    config = function(_, opts)
      local precog = require("precognition")
      precog.setup(opts)

      vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = "*:[vV\x16]*",
        callback = function() precog.show() end,
      })
      vim.api.nvim_create_autocmd("ModeChanged", {
        pattern = "[vV\x16]*:*",
        callback = function() precog.hide() end,
      })
    end,
  },
}
