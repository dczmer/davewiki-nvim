local M = {}

-- ==================================================================
-- CONFIGURATION
-- ==================================================================

local wiki_root = vim.fn.expand(vim.g.davewiki_root or "~/vimwiki")

M.get_wiki_root = function()
    return wiki_root
end

M.get_journal_dir = function()
    return wiki_root .. "/journal"
end

-- ==================================================================
-- UTILITY FUNCTIONS
-- ==================================================================

M.get_relative_path = function(filepath)
    local expanded = vim.fn.expand(filepath)
    local root = vim.fn.expand(wiki_root)
    if expanded:sub(1, #root) == root then
        return expanded:sub(#root + 2)
    end
    return expanded
end

M.get_current_wiki_path = function()
    return M.get_relative_path(vim.api.nvim_buf_get_name(0))
end

M.extract_heading = function(filepath)
    local file = io.open(filepath, "r")
    if not file then
        return nil
    end

    for line in file:lines() do
        local heading = line:match("^#%s+(.+)")
        if heading then
            file:close()
            return heading
        end
    end

    file:close()
    return nil
end

M.ripgrep = function(args)
    local cmd = "rg " .. table.concat(args, " ")
    local handle = io.popen(cmd)
    if not handle then
        return {}
    end

    local result = {}
    for line in handle:lines() do
        table.insert(result, line)
    end
    handle:close()

    return result
end

-- ==================================================================
-- TAG EXTRACTION
-- ==================================================================

M.url_decode = function(str)
    return (str:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

M.url_encode = function(str)
    return (str:gsub("[^%w%-_~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

M.find_tags = function()
    local lines = M.ripgrep({
        "--type=markdown",
        wiki_root,
    })

    local tag_data = {}

    for _, line in ipairs(lines) do
        local link_text, file_path = line:match("%[([^%]]+)%]%(([^%)]+)%)")
        if link_text and file_path and (file_path:match("^%./source/") or file_path:match("^source/")) then
            if link_text:match("^#") then
                local tag = link_text:sub(2)
                local decoded_path = M.url_decode(file_path:gsub("^%./source/", ""):gsub("^source/", ""))

                if not tag_data[tag] then
                    tag_data[tag] = { count = 0, files = {} }
                end
                tag_data[tag].count = tag_data[tag].count + 1

                local found = false
                for _, f in ipairs(tag_data[tag].files) do
                    if f == decoded_path then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(tag_data[tag].files, decoded_path)
                end
            end
        end
    end

    local tags = {}
    for tag, data in pairs(tag_data) do
        table.insert(tags, {
            tag = tag,
            count = data.count,
            files = data.files,
        })
    end

    table.sort(tags, function(a, b)
        if a.count == b.count then
            return a.tag < b.tag
        end
        return a.count > b.count
    end)

    return tags
end

M.convert_word_to_tag_link = function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local col = cursor[2]

    local line = vim.api.nvim_get_current_line()
    local line_length = #line

    local start_col = col
    local end_col = col

    while start_col > 0 and line:sub(start_col, start_col):match("[%w%-_#]") do
        start_col = start_col - 1
    end

    while end_col < line_length and line:sub(end_col + 1, end_col + 1):match("[%w%-_#]") do
        end_col = end_col + 1
    end

    local word = line:sub(start_col + 1, end_col)

    if word:match("^#") then
        local tag_name = word:sub(2)
        local encoded_name = M.url_encode(tag_name)
        local link_text = "#" .. tag_name
        local link = string.format("[%s](source/#%s.md)", link_text, encoded_name)

        local new_line = line:sub(1, start_col) .. link .. line:sub(end_col + 1)
        vim.api.nvim_set_current_line(new_line)
        return true
    end

    return false
end

return M
