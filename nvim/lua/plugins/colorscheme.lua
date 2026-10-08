return {
  -- Default
  {
    "vcraescu/islands-dark.nvim",
    lazy = true,
    opts = {
      -- Match Android Studio's Dart plugin (DartSyntaxHighlighterColors fallbacks)
      overrides = function(c)
        local plain = { fg = c.foreground }
        local field = { fg = c.property, italic = false }
        local static_field = { fg = c.property, italic = true }
        local constructor = { fg = "#57AAF7" } -- DART_CONSTRUCTOR -> DEFAULT_INSTANCE_METHOD
        return {
          -- Treesitter (before dartls attaches / where it emits no token)
          ["@type.dart"] = plain,
          ["@type.builtin.dart"] = plain,
          ["@type.definition.dart"] = plain,
          ["@constructor.dart"] = constructor,
          ["@function.call.dart"] = plain,
          ["@function.method.call.dart"] = plain,
          ["@attribute.dart"] = { fg = c.metadata },
          ["@boolean.dart"] = { fg = c.keyword },
          ["@constant.builtin.dart"] = { fg = c.keyword },
          ["@variable.builtin.dart"] = { fg = c.keyword },
          ["@comment.documentation.dart"] = { fg = c.comment_doc, italic = true },

          -- dartls semantic tokens
          ["@lsp.type.annotation.dart"] = { fg = c.metadata },
          ["@lsp.type.boolean.dart"] = { fg = c.keyword },
          ["@lsp.type.keyword.dart"] = { fg = c.keyword },
          ["@lsp.type.class.dart"] = plain,
          ["@lsp.typemod.class.constructor.dart"] = constructor,
          ["@lsp.type.enum.dart"] = plain,
          ["@lsp.type.type.dart"] = plain,
          ["@lsp.type.typeParameter.dart"] = plain,
          ["@lsp.type.enumMember.dart"] = field,
          ["@lsp.type.function.dart"] = plain,
          ["@lsp.type.method.dart"] = plain,
          ["@lsp.typemod.method.declaration.dart"] = { fg = c.func },
          ["@lsp.typemod.method.static.dart"] = { fg = c.func, italic = true },
          ["@lsp.typemod.method.constructor.dart"] = constructor,
          ["@lsp.type.property.dart"] = static_field,
          ["@lsp.typemod.property.instance.dart"] = field,
          ["@lsp.typemod.property.static.dart"] = static_field,
          ["@lsp.typemod.variable.instance.dart"] = field,
          ["@lsp.typemod.variable.static.dart"] = static_field,
          ["@lsp.typemod.variable.importPrefix.dart"] = plain,
          ["@lsp.type.parameter.dart"] = plain,
          ["@lsp.type.source.dart"] = plain,
          ["@lsp.type.namespace.dart"] = plain,
          ["@lsp.typemod.string.escape.dart"] = { fg = c.escape },
          ["@lsp.typemod.comment.documentation.dart"] = { fg = c.comment_doc, italic = true },

          -- Indent guides (INDENT_GUIDE / SELECTED_INDENT_GUIDE)
          SnacksIndent = { fg = "#323438" },
          SnacksIndentScope = { fg = "#4E5157" },
          SnacksIndentChunk = { fg = "#4E5157" },

          -- Gutter change markers (ADDED/MODIFIED/DELETED_LINES_COLOR)
          GitSignsAdd = { fg = "#549159" },
          GitSignsUntracked = { fg = "#549159" },
          GitSignsChange = { fg = "#375FAD" },
          GitSignsChangedelete = { fg = "#375FAD" },
          GitSignsDelete = { fg = "#868A91" },
          GitSignsTopdelete = { fg = "#868A91" },

          -- Project view (neo-tree): folder roles and FILESTATUS_* colours
          NeoTreeDirectoryName = plain,
          NeoTreeFileName = plain,
          NeoTreeRootName = { fg = c.foreground, bold = true },
          NeoTreeExpander = { fg = "#868A91" },
          NeoTreeDirectoryIcon = { fg = "#868A91" },
          NeoTreeDirectoryIconSource = { fg = "#548AF7" },
          NeoTreeDirectoryIconTest = { fg = "#5FB865" },
          NeoTreeDirectoryIconExcluded = { fg = "#E08855" },
          NeoTreeCursorLine = { bg = "#2E436E" },
          NeoTreeGitModified = { fg = "#70AEFF" },
          NeoTreeGitAdded = { fg = "#73BD79" },
          NeoTreeGitStaged = { fg = "#73BD79" },
          NeoTreeGitUntracked = { fg = "#D1675A" },
          NeoTreeGitUnstaged = { fg = "#70AEFF" },
          NeoTreeGitRenamed = { fg = "#70AEFF" },
          NeoTreeGitDeleted = { fg = "#868A91" },
          NeoTreeGitConflict = { fg = "#D5756C", bold = true },
          NeoTreeGitIgnored = { fg = "#A69D4C" },
          NeoTreeDotfile = plain,
          NeoTreeHiddenByName = { fg = "#868A91" },
        }
      end,
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "islands-dark" } },
  { "folke/snacks.nvim", opts = { indent = { animate = { enabled = false } } } },
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      signs = {
        add = { text = "▌" },
        change = { text = "▌" },
        changedelete = { text = "▌" },
        untracked = { text = "▌" },
      },
      signs_staged = {
        add = { text = "▌" },
        change = { text = "▌" },
        changedelete = { text = "▌" },
      },
    },
  },
  {
    -- Match Android Studio TODO_DEFAULT_ATTRIBUTES (default patterns \btodo\b.* and \bfixme\b.*)
    "folke/todo-comments.nvim",
    opts = {
      merge_keywords = false,
      keywords = {
        TODO = { icon = " ", color = "#8BB33D" },
        FIX = { icon = " ", color = "#8BB33D", alt = { "FIXME" } },
      },
      gui_style = { fg = "italic", bg = "italic" },
      highlight = {
        multiline_pattern = "^%s+%S",
        keyword = "fg",
        after = "fg",
        pattern = [[.*<(KEYWORDS)>]],
      },
      search = { pattern = [[\b(KEYWORDS)\b]] },
    },
  },

  -- Popular dark themes
  { "rebelot/kanagawa.nvim", lazy = true, opts = {
      custom_colors = {
        bg_main = "#000000"
      }
    }
  },
  { "folke/tokyonight.nvim", lazy = true },
  { "catppuccin/nvim", name = "catppuccin", lazy = true },
  { "rose-pine/neovim", name = "rose-pine", lazy = true },
  { "EdenEast/nightfox.nvim", lazy = true },
  { "sainnhe/gruvbox-material", lazy = true },
  { "sainnhe/everforest", lazy = true },
  { "sainnhe/sonokai", lazy = true },
  { "sainnhe/edge", lazy = true },
  { "navarasu/onedark.nvim", lazy = true },
  { "Mofiqul/dracula.nvim", lazy = true },
  { "bluz71/vim-nightfly-colors", name = "nightfly", lazy = true },
  { "bluz71/vim-moonfly-colors", name = "moonfly", lazy = true },
  { "shaunsingh/nord.nvim", lazy = true },
  { "AlexvZyl/nordic.nvim", lazy = true },
  { "marko-cerovac/material.nvim", lazy = true },
  { "projekt0n/github-nvim-theme", lazy = true },
  { "Everblush/nvim", name = "everblush", lazy = true },
  { "scottmckendry/cyberdream.nvim", lazy = true },
  { "ribru17/bamboo.nvim", lazy = true },
  { "neanias/everforest-nvim", lazy = true },
  { "mhartington/oceanic-next", lazy = true },
  { "tiagovla/tokyodark.nvim", lazy = true },
  { "olimorris/onedarkpro.nvim", lazy = true },
  { "rmehri01/onenord.nvim", lazy = true },
  { "Shatur/neovim-ayu", lazy = true },
  { "ellisonleao/gruvbox.nvim", lazy = true },
  { "craftzdog/solarized-osaka.nvim", lazy = true },
  { "HoNamDuong/hybrid.nvim", lazy = true },
  { "0xstepit/flow.nvim", lazy = true },
  { "olivercederborg/poimandres.nvim", lazy = true },
  { "dgox16/oldworld.nvim", lazy = true },
  { "uloco/bluloco.nvim", dependencies = { "rktjmp/lush.nvim" }, lazy = true },
  { "maxmx03/fluoromachine.nvim", lazy = true },
  { "2nthony/vitesse.nvim", dependencies = { "MunifTanjim/nui.nvim" }, lazy = true },
}
