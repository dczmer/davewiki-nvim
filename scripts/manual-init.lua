-- Load this with `:luafile` when doing manual tests and not using `--headless`.

-- setup cmp to test tag/link auto-completion
local cmp = require("cmp")
cmp.setup({
    completion = {
        completeopt = "menu,menuone,preview,noselect",
    },
    mappings = cmp.mapping.preset.insert({
        ["<Up>"] = cmp.mapping.select_prev_item(select_opts),
        ["<Down>"] = cmp.mapping.select_next_item(select_opts),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<CR>"] = cmp.mapping({
            i = function(fallback)
                if cmp.visible() and cmp.get_active_entry() then
                    cmp.confirm({ select = true })
                else
                    fallback()
                end
            end,
            c = cmp.mapping.confirm({ select = true }),
        }),
        ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_next_item(select_opts)
            elseif luasnip.locally_jumpable(1) then
                luasnip.jump(1)
            else
                fallback()
            end
        end, { "i" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
                cmp.select_prev_item(select_opts)
            elseif luasnip.locally_jumpable(-1) then
                luasnip.jump(-1)
            else
                fallback()
            end
        end, { "i" }),
    }),
    sources = cmp.config.sources({
        { name = "nvim_lsp", keyword_length = 1, priority = 1000 },
        { name = "buffer", keyword_length = 3, priority = 500 },
        { name = "path", priority = 250 },
    }),
})

-- setup neotree
require("neo-tree").setup({})
vim.keymap.set("n", "<leader>tt", "<CMD>Neotree toggle<CR>", { desc = "Toggle NeoTree" })

-- setup whichkey
require("which-key").setup({})
vim.keymap.set("n", "<leader>?", function()
    require("which-key").show()
end, { desc = "Show which-key" })

-- setup telescope
local telescope = require("telescope")
telescope.setup({
    defaults = {
        -- Performance: File ignores
        file_ignore_patterns = {
            "^%.git/",
            "result/", -- Nix-specific
            ".direnv/", -- Nix-specific
        },
    },
    pickers = {
        find_files = {
            theme = "dropdown",
            find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
        },
        live_grep = {
            additional_args = function()
                return { "--hidden" }
            end,
        },
    },
})
telescope.load_extension("fzf")
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope Find Files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope Live Grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope Buffers" })

