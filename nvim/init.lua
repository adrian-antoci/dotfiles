-- ============================================================================
-- Bootstrap lazy.nvim (plugin manager)
-- Automatically installs lazy.nvim if not already present
-- ============================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================================
-- General settings
-- ============================================================================
vim.opt.number = true         -- Show absolute line number on current line
vim.opt.relativenumber = true -- Show relative line numbers on other lines
vim.opt.signcolumn = "yes"    -- Always show sign column to prevent layout shift
vim.opt.scrolloff = 999       -- Keep cursor centered while scrolling

-- ============================================================================
-- Diagnostics (inline warnings + floating box on hover)
-- ============================================================================
vim.diagnostic.config({
    virtual_text = true,       -- Show warnings inline after the code
    float = {
        border = "rounded",
        source = true,         -- Show which linter produced the warning
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
vim.opt.updatetime = 300       -- Show floating diagnostic after 300ms


-- Redo
vim.keymap.set("n", "U", "<cmd>redo<cr>", { desc = "Redo" })

-- ============================================================================
-- Navigate back/forward (Cmd+[ / Cmd+])
-- ============================================================================
vim.keymap.set("n", "<M-Left>", "<C-o>", { desc = "Navigate Back" })
vim.keymap.set("n", "<M-Right>", "<C-i>", { desc = "Navigate Forward" })

-- ============================================================================
-- Window navigation (Cmd+h/j/k/l)
-- ============================================================================
vim.keymap.set("n", "<M-h>", "<C-w>h", { desc = "Go to Left Window" })
vim.keymap.set("n", "<M-j>", "<C-w>j", { desc = "Go to Lower Window" })
vim.keymap.set("n", "<M-k>", "<C-w>k", { desc = "Go to Upper Window" })
vim.keymap.set("n", "<M-l>", "<C-w>l", { desc = "Go to Right Window" })

-- ============================================================================
-- Reload config
-- ============================================================================
vim.keymap.set("n", "<leader>lr", function()
    vim.cmd("source $MYVIMRC")
    vim.notify("Config reloaded!", vim.log.levels.INFO)
end, { desc = "Reload init.lua" })

-- ============================================================================
-- Leader key
-- ============================================================================
vim.g.mapleader = " "         -- Set space as the leader key
vim.g.maplocalleader = " "    -- Set space as the local leader key

-- ============================================================================
-- Plugins
-- ============================================================================
require("lazy").setup({
    -- Themes
    {
        "folke/tokyonight.nvim",
        priority = 1000,
        config = function()
            require("tokyonight").setup({ style = "moon" })
            vim.cmd.colorscheme "tokyonight"
        end,
    },
    { "catppuccin/nvim", name = "catppuccin", lazy = true },
    { "rose-pine/neovim", name = "rose-pine", lazy = true },
    { "rebelot/kanagawa.nvim", lazy = true },
    { "EdenEast/nightfox.nvim", lazy = true },
    { "sainnhe/gruvbox-material", lazy = true },
    { "sainnhe/everforest", lazy = true },
    { "navarasu/onedark.nvim", lazy = true },
    { "marko-cerovac/material.nvim", lazy = true },
    { "projekt0n/github-nvim-theme", lazy = true },
    { "Mofiqul/dracula.nvim", lazy = true },
    { "bluz71/vim-nightfly-colors", name = "nightfly", lazy = true },
    { "bluz71/vim-moonfly-colors", name = "moonfly", lazy = true },

    -- Autocompletion
    {
        "hrsh7th/nvim-cmp",
        event = "InsertEnter",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
        },
        config = function()
            local cmp = require("cmp")
            local luasnip = require("luasnip")

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                window = {
                    completion = {
                        border = "rounded",
                        winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel",
                    },
                    documentation = {
                        border = "rounded",
                        winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
                    },
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-n>"] = cmp.mapping.select_next_item(),
                    ["<C-p>"] = cmp.mapping.select_prev_item(),
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<CR>"] = cmp.mapping.confirm({ select = true }),
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                }, {
                    { name = "buffer" },
                    { name = "path" },
                }),
            })
        end,
    },

    -- Tree-sitter: fast, accurate syntax highlighting
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").setup({
                ensure_installed = { "dart", "lua", "yaml", "json", "jsonc", "markdown" },
                highlight = { enable = true },
            })
        end,
    },

    -- Dart syntax highlighting
    { "dart-lang/dart-vim-plugin" },

    -- DAP: debug Flutter apps with breakpoints
    {
        "mfussenegger/nvim-dap",
        lazy = false,
        dependencies = {
            "nvim-neotest/nvim-nio",
            "rcarriga/nvim-dap-ui",
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")
            dapui.setup()

            dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
            dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
            dap.listeners.before.event_exited["dapui"] = function() dapui.close() end

            -- Flutter debug adapter (uses FVM if available)
            local flutter_cmd = "flutter"
            local fvm_flutter = vim.fn.getcwd() .. "/.fvm/flutter_sdk/bin/flutter"
            if vim.uv.fs_stat(fvm_flutter) then flutter_cmd = fvm_flutter end

            dap.adapters.dart = {
                type = "executable",
                command = flutter_cmd,
                args = { "debug_adapter" },
            }

            -- Breakpoints
            vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
            vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Continue" })
            vim.keymap.set("n", "<leader>dn", dap.step_over, { desc = "Step Over" })
            vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Step Into" })
            vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Step Out" })
            vim.keymap.set("n", "<leader>dq", dap.terminate, { desc = "Stop Debug" })
            vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Toggle Debug UI" })
            vim.keymap.set("n", "<leader>dr", function()
                local session = dap.session()
                if session then
                    session:request("hotReload")
                    vim.notify("Hot reloaded", vim.log.levels.INFO)
                end
            end, { desc = "Hot Reload" })
            vim.keymap.set("n", "<leader>dR", function()
                local session = dap.session()
                if session then
                    session:request("hotRestart")
                    vim.notify("Hot restarted", vim.log.levels.INFO)
                end
            end, { desc = "Hot Restart" })
        end,
    },

    -- Dart syntax highlighting
    { "dart-lang/dart-vim-plugin" },

    -- Fuzzy finder (LazyVim style)
    {
        "ibhagwan/fzf-lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("fzf-lua").setup({
                fzf_colors = true,
                winopts = {
                    width = 0.8,
                    height = 0.8,
                    border = "rounded",
                    preview = { layout = "horizontal", horizontal = "right:50%" },
                },
            })
        end,
        keys = {
            { "<leader><space>", "<cmd>FzfLua files<cr>", desc = "Find Files" },
            { "<leader>/", "<cmd>FzfLua live_grep<cr>", desc = "Grep" },
            { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find Files" },
            { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
            { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent Files" },
            { "<leader>sg", "<cmd>FzfLua live_grep<cr>", desc = "Grep" },
            { "<leader>sw", "<cmd>FzfLua grep_cword<cr>", desc = "Word under Cursor" },
            { "<leader>ss", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document Symbols" },
            { "<leader>sS", "<cmd>FzfLua lsp_workspace_symbols<cr>", desc = "Workspace Symbols" },
            { "<leader>sh", "<cmd>FzfLua help_tags<cr>", desc = "Help" },
            { "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
            { "<leader>sc", "<cmd>FzfLua commands<cr>", desc = "Commands" },
            { "<leader>gc", "<cmd>FzfLua git_commits<cr>", desc = "Git Commits" },
            { "<leader>gs", "<cmd>FzfLua git_status<cr>", desc = "Git Status" },
            { "<leader>st", "<cmd>FzfLua colorschemes<cr>", desc = "Themes" },
        },
    },

    -- File explorer (left side)
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
                filesystem = {
                    filtered_items = {
                        visible = true,
                        hide_dotfiles = false,
                        hide_gitignored = false,
                    },
                    use_libuv_file_watcher = true, -- Auto-refresh on file changes
                },
            })
        end,
    },

    -- Floating popups for code actions, rename, etc.
    {
        "stevearc/dressing.nvim",
        event = "VeryLazy",
        config = function()
            require("dressing").setup({
                input = {
                    border = "rounded",
                    relative = "cursor",
                },
                select = {
                    backend = { "fzf_lua" },
                    fzf_lua = {
                        winopts = {
                            width = 0.5,
                            height = 0.4,
                            relative = "cursor",
                            row = 1,
                            col = 0,
                        },
                    },
                },
            })
        end,
    },

    -- Trouble: diagnostics list
    {
        "folke/trouble.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        keys = {
            { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics" },
        },
        config = function()
            require("trouble").setup({
                open_no_results = true,
            })
        end,
    },

    -- Statusline with diagnostic counts
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        event = "VeryLazy",
        config = function()
            require("lualine").setup({
                options = {
                    theme = "auto",
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
})

-- ============================================================================
-- Dart LSP (native Neovim 0.11)
-- ============================================================================
local dart_cmd = "dart"
local fvm_path = vim.fn.getcwd() .. "/.fvm/flutter_sdk/bin/dart"
if vim.uv.fs_stat(fvm_path) then dart_cmd = fvm_path end

vim.lsp.config("dartls", {
    cmd = { dart_cmd, "language-server", "--protocol=lsp" },
    filetypes = { "dart" },
    root_markers = { "pubspec.yaml" },
    capabilities = (function()
        local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
        if ok then return cmp_lsp.default_capabilities() end
        return vim.lsp.protocol.make_client_capabilities()
    end)(),
})
vim.lsp.enable("dartls")

-- LSP keymaps (apply when any LSP attaches)
vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(ev)
        local opts = { buffer = ev.buf }
        vim.keymap.set("n", "cd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "cr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "ch", function() vim.lsp.buf.hover({ border = "rounded" }) end, opts)
        vim.keymap.set("n", "ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "cn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "cf", function() vim.lsp.buf.format({ async = true }) end, opts)

        -- Format and save on leaving insert mode
        vim.api.nvim_create_autocmd("InsertLeave", {
            buffer = ev.buf,
            callback = function()
                if not vim.bo[ev.buf].modified then return end
                local view = vim.fn.winsaveview()
                vim.lsp.buf.format({ async = false })
                vim.cmd("silent! write")
                vim.fn.winrestview(view)
            end,
        })
    end,
})

-- ============================================================================
-- File explorer toggle (Space+e)
-- ============================================================================
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle Explorer" })

-- ============================================================================
-- Terminal toggle (Space+p)
-- ============================================================================
local term_open = false

vim.keymap.set("n", "<leader>p", function()
    if term_open then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "terminal" then
                vim.api.nvim_win_close(win, true)
            end
        end
        term_open = false
    else
        vim.cmd("botright 8split | terminal")
        vim.cmd("setlocal nonumber norelativenumber signcolumn=no")
        vim.cmd("stopinsert")
        vim.cmd("wincmd k")
        term_open = true
    end
end, { desc = "Toggle Terminal" })

-- Open terminal on startup
vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        vim.defer_fn(function()
            vim.cmd("botright 8split | terminal")
            vim.cmd("setlocal nonumber norelativenumber signcolumn=no")
            vim.cmd("stopinsert")
            vim.cmd("wincmd k")
            term_open = true
        end, 50)
    end,
})

-- Terminal keybindings
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit Terminal Mode" })

-- ============================================================================
-- Flutter run/debug via .vscode/launch.json (leader+r / leader+rd / leader+rs)
-- ============================================================================
local function parse_launch_json()
    local launch_path = vim.fn.getcwd() .. "/.vscode/launch.json"
    if not vim.uv.fs_stat(launch_path) then return nil end
    local content = table.concat(vim.fn.readfile(launch_path), "\n")
    content = content:gsub("//.-\n", "\n")
    local ok, launch = pcall(vim.fn.json_decode, content)
    if not ok or not launch.configurations then return nil end
    local configs = {}
    for _, cfg in ipairs(launch.configurations) do
        if cfg.request == "launch" then
            table.insert(configs, cfg)
        end
    end
    return configs
end

local function build_flutter_cmd(cfg)
    local flutter = "flutter"
    local fvm = vim.fn.getcwd() .. "/.fvm/flutter_sdk/bin/flutter"
    if vim.uv.fs_stat(fvm) then flutter = fvm end

    local cwd = vim.fn.getcwd()
    if cfg.cwd then cwd = vim.fn.getcwd() .. "/" .. cfg.cwd end

    local parts = { flutter, "run" }
    if cfg.program then
        table.insert(parts, "-t")
        table.insert(parts, cfg.program)
    end
    if cfg.args then
        for _, arg in ipairs(cfg.args) do
            table.insert(parts, arg)
        end
    end
    return table.concat(parts, " "), cwd
end

local function pick_and_run(debug_mode)
    local configs = parse_launch_json()
    if not configs or #configs == 0 then
        vim.notify("No launch configs found in .vscode/launch.json", vim.log.levels.WARN)
        return
    end

    vim.ui.select(configs, {
        prompt = debug_mode and "Debug config: " or "Run config: ",
        format_item = function(cfg) return cfg.name end,
    }, function(cfg)
        if not cfg then return end

        if debug_mode then
            -- Run via DAP for breakpoint support
            local cwd = vim.fn.getcwd()
            if cfg.cwd then cwd = vim.fn.getcwd() .. "/" .. cfg.cwd end

            local dap_config = {
                type = "dart",
                request = "launch",
                name = cfg.name,
                program = cfg.program or "lib/main.dart",
                cwd = cwd,
                args = cfg.args or {},
            }
            require("dap").run(dap_config)
        else
            -- Run in terminal
            local cmd, cwd = build_flutter_cmd(cfg)
            vim.cmd("botright 10split | terminal cd " .. vim.fn.shellescape(cwd) .. " && " .. cmd)
            vim.cmd("setlocal nonumber norelativenumber signcolumn=no")
            vim.cmd("stopinsert")
            vim.cmd("wincmd k")
        end
    end)
end

vim.keymap.set("n", "<leader>r", function() pick_and_run(false) end, { desc = "Run Flutter" })
vim.keymap.set("n", "<leader>rd", function() pick_and_run(true) end, { desc = "Debug Flutter" })
vim.keymap.set("n", "<leader>rs", function()
    -- Stop running app (kill terminal or DAP)
    pcall(function() require("dap").terminate() end)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "terminal" then
            pcall(vim.fn.jobstop, vim.bo[buf].channel)
            vim.api.nvim_win_close(win, true)
        end
    end
end, { desc = "Stop Flutter" })
