-- Render image files inline (kitty graphics protocol) and show file info in the winbar
return {
  {
    "3rd/image.nvim",
    build = false, -- don't build the luarocks magick dependency; shell out to magick CLI instead
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      max_width_window_percentage = 80,
      max_height_window_percentage = 60,
      window_overlap_clear_enabled = true,
      hijack_file_patterns = {
        "*.png",
        "*.jpg",
        "*.jpeg",
        "*.gif",
        "*.webp",
        "*.avif",
        "*.bmp",
        "*.ico",
        "*.tiff",
      },
    },
    config = function(_, opts)
      require("image").setup(opts)

      local group = vim.api.nvim_create_augroup("image-file-info", { clear = true })

      local function human_size(bytes)
        local units = { "B", "KB", "MB", "GB" }
        local i, size = 1, bytes
        while size >= 1024 and i < #units do
          size = size / 1024
          i = i + 1
        end
        return string.format(i == 1 and "%d %s" or "%.1f %s", size, units[i])
      end

      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = group,
        pattern = opts.hijack_file_patterns,
        callback = function(args)
          local path = args.file
          local res = vim
            .system({ "magick", "identify", "-ping", "-format", "%m · %wx%h · %z-bit %[colorspace]", path })
            :wait()
          local meta = (res.code == 0 and res.stdout ~= "") and vim.trim(res.stdout:gsub("\n", "")) or nil

          local stat = vim.uv.fs_stat(path)
          local parts = { vim.fn.fnamemodify(path, ":t"), meta }
          if stat then
            parts[#parts + 1] = human_size(stat.size)
          end
          local bar = "IMG  " .. table.concat(vim.tbl_filter(function(p)
            return p ~= nil
          end, parts), "  │  ")

          for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
            vim.api.nvim_set_option_value("winbar", bar, { win = win })
          end
        end,
      })
    end,
  },
}
