-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true


-- Show diagnostics on hover
vim.diagnostic.config({
    virtual_text = true,
    float = {
        border = "rounded",
        source = true,
    },
})
vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
        vim.diagnostic.open_float(nil, {
            focusable = false,
            border = "rounded",
            anchor_bias = "below",
        })
    end,
})
vim.opt.updatetime = 300

-- Rounded borders for all floating windows (hover, signature, etc.)
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

-- Set space as leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- LazyVim-style keymaps
local map = vim.keymap.set

-- Move between windows
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window" })

-- Resize windows
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Move lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move Down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move Up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move Down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move Up" })

-- Buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })


-- Toggle terminal
local term_buf = nil
local term_win = nil

local function toggle_terminal()
    if term_win and vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_hide(term_win)
        term_win = nil
    else
        vim.cmd("botright 15split")
        if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
            vim.api.nvim_set_current_buf(term_buf)
        else
            vim.cmd("terminal")
            term_buf = vim.api.nvim_get_current_buf()
        end
        term_win = vim.api.nvim_get_current_win()
        vim.cmd("setlocal nonumber norelativenumber signcolumn=no")
        vim.cmd("startinsert")
    end
end

map("n", "<leader>T", toggle_terminal, { desc = "Toggle Terminal" })
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit Terminal Mode" })
map("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Move to Window Below" })
map("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Move to Window Above" })

-- Auto enter insert mode when focusing terminal
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "term://*",
    callback = function() vim.cmd("startinsert") end,
})

-- Open terminal and git status on startup
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        vim.defer_fn(function()
            toggle_terminal()
            -- Exit terminal mode, split vertically for git status
            vim.cmd("stopinsert")
            vim.cmd("vsplit")
            vim.cmd("Neotree git_status position=current")
            -- Focus editor
            vim.cmd("wincmd k")
        end, 100)
    end,
})

-- Save
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

-- Better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Clear search
map({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Clear Search" })

require("lazy").setup({
    {
        "folke/tokyonight.nvim",
        priority = 1000,
        config = function()
            require("tokyonight").setup({
                style = "moon",
            })
            vim.cmd.colorscheme "tokyonight"
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").setup({
                ensure_installed = { "dart", "lua", "yaml", "json", "markdown" },
            })
            vim.treesitter.language.register("dart", "dart")
        end,
    },
    {
        "dart-lang/dart-vim-plugin",
    },
    {
        "nvim-lua/plenary.nvim",
    },
    {
        "akinsho/flutter-tools.nvim",
        lazy = false,
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("flutter-tools").setup({
                dev_log = {
                    open_cmd = "botright 15split",
                },
                widget_guides = { enabled = true },
                lsp = {
                    capabilities = function(config)
                        local ok, blink = pcall(require, "blink.cmp")
                        if ok then
                            config.capabilities = blink.get_lsp_capabilities(config.capabilities)
                        end
                        return config
                    end,
                    on_attach = function(client, bufnr)
                        local opts = { buffer = bufnr }
                        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
                        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
                        vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, opts)
                        vim.keymap.set("n", "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, opts)

                        -- Format and save on leaving insert mode
                        vim.api.nvim_create_autocmd("InsertLeave", {
                            buffer = bufnr,
                            callback = function()
                                local view = vim.fn.winsaveview()
                                vim.lsp.buf.format({ async = false })
                                vim.cmd("write")
                                vim.fn.winrestview(view)
                            end,
                        })
                    end,
                },
                fvm = true,
            })
        end,
    },
    {
        "saghen/blink.cmp",
        version = "*",
        event = { "InsertEnter", "CmdlineEnter" },
        dependencies = { "rafamadriz/friendly-snippets" },
        opts = {
            keymap = {
                preset = "default",
                ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
                ["<C-e>"] = { "hide" },
                ["<CR>"] = { "accept", "fallback" },
                ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
                ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
                ["<C-b>"] = { "scroll_documentation_up", "fallback" },
                ["<C-f>"] = { "scroll_documentation_down", "fallback" },
            },
            completion = {
                accept = { auto_brackets = { enabled = true } },
                menu = { draw = { treesitter = { "lsp" } } },
                documentation = { auto_show = true, auto_show_delay_ms = 200 },
            },
            signature = { enabled = true },
            sources = {
                default = { "lsp", "path", "snippets", "buffer" },
            },
            cmdline = {
                enabled = true,
                completion = {
                    menu = { auto_show = true },
                },
            },
        },
    },
    {
        "ibhagwan/fzf-lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("fzf-lua").setup({
                winopts = { border = "rounded" },
            })
        end,
    },
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        config = function()
            local wk = require("which-key")
            wk.setup({
                preset = "helix",
                win = {
                    border = "rounded",
                },
            })
            wk.add({
                -- File Explorer
                { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Explorer" },

                -- Find / File
                { "<leader>f", group = "Find/File" },
                { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find Files" },
                { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Grep (Search Text)" },
                { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Find Buffers" },
                { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent Files" },
                { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Find Symbols (file)" },
                { "<leader>fS", "<cmd>FzfLua lsp_workspace_symbols<cr>", desc = "Find Symbols (workspace)" },
                { "<leader>fn", "<cmd>enew<cr>", desc = "New File" },
                -- Search
                { "<leader>s", group = "Search" },
                { "<leader>sf", "<cmd>FzfLua files<cr>", desc = "Files" },
                { "<leader>sg", "<cmd>FzfLua live_grep<cr>", desc = "Grep" },
                { "<leader>sw", "<cmd>FzfLua grep_cword<cr>", desc = "Word under Cursor" },
                { "<leader>sh", "<cmd>FzfLua help_tags<cr>", desc = "Help" },
                { "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
                { "<leader>sc", "<cmd>FzfLua commands<cr>", desc = "Commands" },

                -- Buffers
                { "<leader>b", group = "Buffers" },
                { "<leader>bd", "<cmd>bdelete<cr>", desc = "Delete Buffer" },
                { "<leader>bb", "<cmd>e #<cr>", desc = "Switch to Other Buffer" },
                { "<leader>bo", "<cmd>%bdelete|edit#|bdelete#<cr>", desc = "Delete Other Buffers" },

                -- Windows
                { "<leader>w", group = "Windows" },
                { "<leader>wd", "<C-w>c", desc = "Delete Window" },
                { "<leader>w-", "<C-w>s", desc = "Split Below" },
                { "<leader>w|", "<C-w>v", desc = "Split Right" },
                { "<leader>-", "<C-w>s", desc = "Split Below" },
                { "<leader>|", "<C-w>v", desc = "Split Right" },

                -- Tabs
                { "<leader><tab>", group = "Tabs" },
                { "<leader><tab><tab>", "<cmd>tabnew<cr>", desc = "New Tab" },
                { "<leader><tab>d", "<cmd>tabclose<cr>", desc = "Close Tab" },
                { "<leader><tab>]", "<cmd>tabnext<cr>", desc = "Next Tab" },
                { "<leader><tab>[", "<cmd>tabprevious<cr>", desc = "Previous Tab" },
                { "<leader><tab>l", "<cmd>tablast<cr>", desc = "Last Tab" },
                { "<leader><tab>f", "<cmd>tabfirst<cr>", desc = "First Tab" },
                { "<leader><tab>o", "<cmd>tabonly<cr>", desc = "Close Other Tabs" },

                -- Quit
                { "<leader>q", group = "Quit/Session" },
                { "<leader>qq", "<cmd>qa<cr>", desc = "Quit All" },

                -- Code / LSP
                { "<leader>c", group = "Code" },
                { "<leader>ca", vim.lsp.buf.code_action, desc = "Code Action" },
                { "<leader>cd", vim.diagnostic.open_float, desc = "Line Diagnostics" },
                { "<leader>cr", vim.lsp.buf.rename, desc = "Rename" },
                { "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, desc = "Format" },

                -- Git
                { "<leader>g", group = "Git" },
                { "<leader>gs", "<cmd>Neotree git_status<cr>", desc = "Git Status" },

                -- LSP
                { "<leader>l", group = "LSP" },
                { "<leader>li", "<cmd>LspInfo<cr>", desc = "LSP Info" },
                { "<leader>lr", "<cmd>LspRestart<cr>", desc = "LSP Restart" },

                -- UI Toggles
                { "<leader>u", group = "UI" },
                { "<leader>uw", "<cmd>set wrap!<cr>", desc = "Toggle Wrap" },
                { "<leader>ul", "<cmd>set number!<cr>", desc = "Toggle Line Numbers" },
                { "<leader>uL", "<cmd>set relativenumber!<cr>", desc = "Toggle Relative Numbers" },
                { "<leader>us", "<cmd>set spell!<cr>", desc = "Toggle Spelling" },

                -- Diagnostics / Quickfix
                { "<leader>x", group = "Diagnostics/Quickfix" },
                { "<leader>xx", vim.diagnostic.setloclist, desc = "All Diagnostics (buffer)" },
                { "<leader>xX", vim.diagnostic.setqflist, desc = "All Diagnostics (workspace)" },
                { "<leader>xl", "<cmd>lopen<cr>", desc = "Location List" },
                { "<leader>xq", "<cmd>copen<cr>", desc = "Quickfix List" },

                -- Navigation
                { "]d", vim.diagnostic.goto_next, desc = "Next Diagnostic" },
                { "[d", vim.diagnostic.goto_prev, desc = "Previous Diagnostic" },
                { "gd", vim.lsp.buf.definition, desc = "Go to Definition" },
                { "gr", vim.lsp.buf.references, desc = "Go to References" },
                { "gI", vim.lsp.buf.implementation, desc = "Go to Implementation" },
                { "gy", vim.lsp.buf.type_definition, desc = "Go to Type Definition" },
                { "K", vim.lsp.buf.hover, desc = "Hover" },
                { "gK", vim.lsp.buf.signature_help, desc = "Signature Help" },

                -- Flutter
                { "<leader>F", group = "Flutter" },
                { "<leader>Fr", "<cmd>FlutterRun<cr>", desc = "Flutter Run" },
                { "<leader>Fq", "<cmd>FlutterQuit<cr>", desc = "Flutter Quit" },
                { "<leader>FR", "<cmd>FlutterReload<cr>", desc = "Flutter Reload" },
                { "<leader>Fs", "<cmd>FlutterRestart<cr>", desc = "Flutter Restart" },
                { "<leader>Fd", "<cmd>FlutterDevices<cr>", desc = "Flutter Devices" },
                { "<leader>Fo", "<cmd>FlutterOutlineToggle<cr>", desc = "Flutter Outline" },
                { "<leader>Fl", "<cmd>FlutterLogClear<cr>", desc = "Flutter Clear Log" },

                -- Lazy
                { "<leader>L", "<cmd>Lazy<cr>", desc = "Lazy (Plugin Manager)" },
            })
        end,
    },
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "VeryLazy",
        config = function()
            require("lualine").setup({
                options = {
                    theme = "tokyonight",
                    globalstatus = true,
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch", "diff" },
                    lualine_c = { "filename" },
                    lualine_x = { "diagnostics", "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
            })
        end,
    },
    {
        "akinsho/bufferline.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "VeryLazy",
        config = function()
            require("bufferline").setup({
                options = {
                    always_show_bufferline = true,
                    diagnostics = "nvim_lsp",
                    offsets = {
                        { filetype = "neo-tree", text = "File Explorer", highlight = "Directory", separator = true },
                    },
                },
            })
        end,
    },
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        config = function()
            require("neo-tree").setup({
                window = {
                    position = "left",
                },
                git_status = {
                    window = {
                        position = "current",
                        mappings = {
                            ["<cr>"] = function(state)
                                local node = state.tree:get_node()
                                if node.type == "file" then
                                    -- Find the editor window (not terminal, not neo-tree)
                                    for _, win in ipairs(vim.api.nvim_list_wins()) do
                                        local buf = vim.api.nvim_win_get_buf(win)
                                        local bt = vim.bo[buf].buftype
                                        local ft = vim.bo[buf].filetype
                                        if bt ~= "terminal" and ft ~= "neo-tree" then
                                            vim.api.nvim_set_current_win(win)
                                            vim.cmd("edit " .. node.path)
                                            return
                                        end
                                    end
                                end
                            end,
                        },
                    },
                    follow_current_file = { enabled = true },
                },
                open_files_do_not_replace_types = { "terminal", "neo-tree", "qf" },
                filesystem = {
                    use_libuv_file_watcher = true,
                },
            })
        end,
    },
})
