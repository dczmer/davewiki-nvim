local M = {}

-- ==================================================================
-- CONFIGURATION
-- ==================================================================

--- Returns the wiki root directory path.
--- Expands vim.g.davewiki_root if set, otherwise defaults to ~/vimwiki.
--- @return string The expanded wiki root directory path
M.get_wiki_root = function()
    return vim.fn.expand(vim.g.davewiki_root or "~/vimwiki")
end

--- Returns the journal directory path within the wiki root.
--- @return string The journal directory path (wiki_root/journal)
M.get_journal_dir = function()
    return M.get_wiki_root() .. "/journal"
end

-- ==================================================================
-- UTILITY FUNCTIONS
-- ==================================================================

--- Converts an absolute filepath to a relative path from the wiki root.
--- If the filepath is not within the wiki root, returns the expanded path unchanged.
--- @param filepath string The absolute or relative filepath to convert
--- @return string The relative path from wiki root, or the expanded path if outside root
M.get_relative_path = function(filepath)
    local expanded = vim.fn.expand(filepath)
    local root = M.get_wiki_root()
    if expanded:sub(1, #root) == root then
        return expanded:sub(#root + 2)
    end
    return expanded
end

--- Returns the relative path of the current buffer from the wiki root.
--- Uses the current buffer's filename (buffer 0).
--- @return string The relative path of the current buffer
M.get_current_wiki_path = function()
    return M.get_relative_path(vim.api.nvim_buf_get_name(0))
end

--- Extracts the first markdown heading from a file.
--- Searches for lines starting with "# " and returns the heading text.
--- @param filepath string The path to the file to read
--- @return string|nil The heading text without the "# " prefix, or nil if not found or file cannot be opened
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

--- Executes a ripgrep command and returns the matching lines.
--- Constructs a shell command from the provided arguments and captures output.
--- @param args table Array of string arguments to pass to ripgrep
--- @return table Array of matching lines from ripgrep output, or empty table on failure
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
-- TAG SEARCHING AND EXTRACTION
-- ==================================================================

--- Decodes URL-encoded characters in a string.
--- Converts %XX sequences back to their original characters.
--- @param str string The URL-encoded string to decode
--- @return string The decoded string with %XX sequences replaced by actual characters
M.url_decode = function(str)
    return (str:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

--- Encodes special characters in a string for use in URLs.
--- Preserves alphanumeric characters, hyphens, underscores, and tildes.
--- @param str string The string to encode
--- @return string The URL-encoded string with special characters as %XX sequences
M.url_encode = function(str)
    return (str:gsub("[^%w%-_~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

--- Finds all tags in the wiki by searching for markdown links to source files.
--- Searches for patterns like [#tagname](source/#tagname.md) across all markdown files.
--- Aggregates tags by name and tracks which files link to each tag.
--- @return table Array of tag objects sorted by count (descending), each with:
---   - tag: string - the tag name (without # prefix)
---   - count: number - total number of occurrences
---   - files: table - array of source file paths that link to this tag
M.find_tags = function()
    local lines = M.ripgrep({
        "--type=markdown",
        "'\\[#'",
        M.get_wiki_root(),
    })

    local tag_data = {}

    for _, line in ipairs(lines) do
        local link_text, file_path = line:match("%[#([^%]]+)%]%(([^%)]+)%)")
        if link_text and file_path and (file_path:match("^%./source/") or file_path:match("^source/")) then
            link_text = "#" .. link_text
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
                    table.insert(tag_data[tag].files, "source/" .. decoded_path)
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

--- Finds all files containing tag links, optionally filtered by a specific tag.
--- Searches for markdown links like [#tagname](source/#tagname.md) and returns
--- the source files that contain these links (not the link targets).
--- @param tag_name string|nil Optional tag name to filter results. If nil, finds all tag links.
--- @return table Array of file objects sorted by tag count (descending), each with:
---   - filepath: string - relative path from wiki root
---   - count: number - number of unique tags in this file
---   - tags: table - array of tag strings (with # prefix) found in this file
M.find_tag_links = function(tag_name)
    local pattern = tag_name and string.format("'\\[#%s\\]'", tag_name) or "'\\[#'"
    local lines = M.ripgrep({
        "--type=markdown",
        pattern,
        M.get_wiki_root(),
    })

    local file_data = {}

    for _, line in ipairs(lines) do
        local source_file, link_text = line:match("^([^:]+):.*%[#([^%]]+)%]")
        if source_file and link_text then
            if not tag_name or link_text == tag_name then
                local relative_path = M.get_relative_path(source_file)
                local tag = "#" .. link_text

                if not file_data[relative_path] then
                    file_data[relative_path] = { count = 0, tags = {} }
                end

                local found = false
                for _, t in ipairs(file_data[relative_path].tags) do
                    if t == tag then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(file_data[relative_path].tags, tag)
                    file_data[relative_path].count = file_data[relative_path].count + 1
                end
            end
        end
    end

    local files = {}
    for filepath, data in pairs(file_data) do
        table.insert(files, {
            filepath = filepath,
            count = data.count,
            tags = data.tags,
        })
    end

    table.sort(files, function(a, b)
        if a.count == b.count then
            return a.filepath < b.filepath
        end
        return a.count > b.count
    end)

    return files
end

--- Converts the word under the cursor to a markdown tag link.
--- If the cursor is on a word starting with #, replaces it with a markdown link
--- in the format [#tagname](source/#tagname.md). URL-encodes the tag name in the link.
--- Operates on the current buffer and modifies the current line in place.
--- @return boolean true if conversion succeeded, false if word doesn't start with #
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

--- Opens the tag file if cursor is over a markdown link to a tag file.
--- Checks if cursor is positioned within a markdown link pattern like [#tag](source/#tag.md).
--- If found and it's a tag link, opens the target file in the current buffer.
--- @return boolean true if a tag link was found and opened, false otherwise
M.follow_tag_link = function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local col = cursor[2]

    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    if not line then
        return false
    end

    local function find_link_at_cursor()
        local start_pos = 1
        while true do
            local link_start, link_end, link_text, link_url = line:find("%[([^%]]+)%]%(([^%)]+)%)", start_pos)
            if not link_start then
                return nil
            end

            local link_col_start = link_start - 1
            local link_col_end = link_end - 1

            if col >= link_col_start and col <= link_col_end then
                return link_text, link_url
            end

            start_pos = link_end + 1
        end
    end

    local _, link_url = find_link_at_cursor()
    if not link_url then
        return false
    end

    if link_url:match("^%./source/") or link_url:match("^source/") then
        local decoded_path = M.url_decode(link_url:gsub("^%./", ""):gsub("^source/", "source/"))
        local full_path = M.get_journal_dir() .. "/" .. decoded_path

        if vim.fn.filereadable(full_path) == 1 then
            vim.cmd("edit " .. vim.fn.fnameescape(full_path))
            return true
        else
            local dir = vim.fn.fnamemodify(full_path, ":h")
            vim.fn.mkdir(dir, "p")

            local tag_name = decoded_path:match("#([^/]+)%.md$")
            if tag_name then
                local file = io.open(full_path, "w")
                if file then
                    file:write("# " .. tag_name .. "\n")
                    file:close()
                end
            end

            vim.cmd("edit " .. vim.fn.fnameescape(full_path))
            return true
        end
    end

    return false
end

return M
