return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          -- Grep literally: pasted strings with regex metacharacters
          -- (. ( ) [ ] $ * + etc.) match verbatim. `regex = false` makes
          -- Snacks pass `--fixed-strings` to ripgrep. Affects <leader>/,
          -- <leader>sg and every other grep picker.
          grep = { regex = false },
          grep_buffers = { regex = false },
          grep_word = { regex = false },
        },
      },
    },
  },
}
