return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          projects = {
            dev = {
              "~/Repos",
              "~/dotfiles",
            },
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
            -- same layout path as a normal nvim start
            confirm = function(picker, item)
              picker:close()
              if not item then
                return
              end
              require("config.side_panels").open_project(item.file)
            end,
          },
        },
      },
    },
  },
}
