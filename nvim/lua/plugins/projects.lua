return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          projects = {
            -- parent dirs whose immediate children are projects (git roots, etc.)
            dev = {
              "~/Repos",
              "~/dotfiles",
            },
            -- explicit single-repo paths (not under a scanned parent)
            projects = {
              "~/dotfiles",
              "~/immich",
              "~/gitea-proxmox",
            },
            recent = true,
            patterns = {
              ".git",
              "package.json",
              "pubspec.yaml",
              "Cargo.toml",
              "go.mod",
              "Makefile",
              "CMakeLists.txt",
            },
            -- after switching project, restore side panels (session wipe otherwise)
            actions = {
              load_session = function(picker, item)
                -- default snacks behavior
                require("snacks.picker.actions").load_session(picker, item)
                vim.defer_fn(function()
                  require("config.side_panels").ensure({ force = true })
                end, 150)
              end,
            },
            confirm = "load_session",
          },
        },
      },
    },
  },
}
