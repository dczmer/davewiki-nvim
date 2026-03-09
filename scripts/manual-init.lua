-- Load this with `:luafile` when doing manual tests and not using `--headless`.

-- setup cmp to test tag/link auto-completion
local cmp = require("cmp")
require("davewiki-cmp").setup()
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
        { name = "wiki_tags", keyword_length = 1, priority = 800 },
        { name = "buffer", keyword_length = 3, priority = 500 },
        { name = "path", priority = 250 },
    }),
})

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

-- ==================================================================
-- WIKI KEY MAPPINGS (<leader>w = wiki)
-- ==================================================================

local journal = require("davewiki-journal")
local wiki_telescope = require("davewiki-telescope")

vim.keymap.set("n", "<leader>wj", journal.today, { desc = "Wiki: Today's journal" })
vim.keymap.set("n", "<leader>wy", journal.yesterday, { desc = "Wiki: Yesterday's journal" })
vim.keymap.set("n", "<leader>wT", journal.tomorrow, { desc = "Wiki: Tomorrow's journal" })
vim.keymap.set("n", "<leader>wJ", journal.browse, { desc = "Wiki: Browse journals" })
vim.keymap.set("n", "<leader>wc", journal.calendar, { desc = "Wiki: Go to date" })
vim.keymap.set("n", "<leader>wh", wiki_telescope.search_headings, { desc = "Wiki: Search headings" })
vim.keymap.set("n", "<leader>w#", wiki_telescope.search_tags, { desc = "Wiki: Browse tags" })
vim.keymap.set("n", "<leader>wi", wiki_telescope.insert_tag, { desc = "Wiki: Insert tag" })
vim.keymap.set("n", "<leader>wb", wiki_telescope.backlinks, { desc = "Wiki: Backlinks" })

local wiki = require("davewiki-core")
vim.keymap.set("n", "<CR>", wiki.create_tag_or_open_link, { desc = "Wiki: Open link or convert to tag" })
