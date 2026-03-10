-- ==================================================================
-- WIKI TAG AUTOCOMPLETE SOURCE FOR NVIM-CMP
-- ==================================================================

local wiki = require("davewiki-core")

-- ==================================================================
-- CMP SOURCE IMPLEMENTATION
-- ==================================================================

local source = {}

source.new = function()
    return setmetatable({}, { __index = source })
end

source.get_keyword_pattern = function()
    return [[\#[a-zA-Z0-9_-]+]]
end

source.is_available = function()
    local bufpath = vim.api.nvim_buf_get_name(0)
    local wiki_root = vim.fn.expand(wiki.get_wiki_root())
    return vim.bo.filetype == "markdown" and bufpath:sub(1, #wiki_root) == wiki_root
end

source.complete = function(_, params, callback)
    local input = string.sub(params.context.cursor_before_line, params.offset)

    if not input:match("^#") then
        callback({ items = {}, isIncomplete = false })
        return
    end

    local tags = wiki.find_tags()

    local items = {}
    for _, tag_data in ipairs(tags) do
        table.insert(items, {
            label = "#" .. tag_data.tag,
            kind = require("cmp").lsp.CompletionItemKind.Text,
            documentation = "Used " .. tag_data.count .. " times",
            insertText = tag_data.tag,
        })
    end

    callback({ items = items, isIncomplete = false })
end

return {
    setup = function()
        local cmp = require("cmp")
        cmp.register_source("wiki_tags", source.new())
        return source
    end,
}
