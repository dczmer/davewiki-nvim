local core = require("davewiki-core")

local wiki_root = core.get_wiki_root()
vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = wiki_root .. "/source/#*.md",
    callback = function()
        core.backlink_qfix(vim.api.nvim_buf_get_name(0))
    end,
    desc = "Populate quickfix list with unlinked tags when opening a tag file",
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "qf",
    callback = function()
        -- I'm not sure why this works, but CR doesn't jump to the file without it.
        vim.keymap.set("n", "<CR>", "<CR>", { buffer = true, desc = "Open file at quickfix entry" })
    end,
    desc = "Map Enter to open file in quickfix buffer",
})
