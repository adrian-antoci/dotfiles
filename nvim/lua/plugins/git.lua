return {
  -- Git commit graph ("git tree") viewer
  {
    "isakbm/gitgraph.nvim",
    dependencies = { "sindrets/diffview.nvim" },
    ---@type I.GGConfig
    opts = {
      git_cmd = "git",
      format = {
        timestamp = "%H:%M:%S %d-%m-%Y",
        fields = { "hash", "timestamp", "author", "branch_name", "tag" },
      },
      hooks = {
        -- Open Diffview for the commit under the cursor
        on_select_commit = function(commit)
          vim.cmd(":DiffviewOpen " .. commit.hash .. "^!")
        end,
        -- Open Diffview for the selected commit range
        on_select_range_commit = function(from, to)
          vim.cmd(":DiffviewOpen " .. from.hash .. "~1.." .. to.hash)
        end,
      },
    },
    keys = {
      {
        "<leader>gt",
        function()
          require("gitgraph").draw({}, { all = true, max_count = 5000 })
        end,
        desc = "Git Tree (GitGraph)",
      },
    },
  },
}
