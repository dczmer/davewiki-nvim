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
--- Uses vim.system() to avoid shell injection vulnerabilities.
--- @param args table Array of string arguments to pass to ripgrep
--- @return table Array of matching lines from ripgrep output, or empty table on failure
M.ripgrep = function(args)
    local result = vim.system({ "rg", unpack(args) }, { text = true }):wait()

    if result.code ~= 0 then
        return {}
    end

    local lines = {}
    for line in result.stdout:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    return lines
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
        '\\[#',
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

--- Finds all backlinks to a given path in the wiki.
--- Searches all markdown files for links pointing to the specified path.
--- @param target_path string The relative path to find backlinks for
--- @return table Array of backlink objects, each with:
---   - path: string - relative path of the file containing the link
---   - line: number - line number where the link appears
---   - content: string - the line content
M.get_backlinks = function(target_path)
    if not target_path or target_path == "" then
        return {}
    end

    local filename = vim.fn.fnamemodify(target_path, ":t")
    local lines = M.ripgrep({
        "--type=markdown",
        "--line-number",
        "--with-filename",
        "-F",
        target_path,
        M.get_wiki_root(),
    })

    local backlinks = {}
    for _, line in ipairs(lines) do
        local filepath, lnum, content = line:match("^([^:]+):(%d+):(.+)$")
        if filepath and lnum and content then
            local relative_path = M.get_relative_path(filepath)
            if relative_path ~= target_path then
                local has_link = content:match("%[[^%]]*%]%([^%)]*" .. vim.pesc(target_path) .. "[^%)]*%)")
                    or content:match("%[%[" .. vim.pesc(target_path) .. "%]%]")
                    or content:match("%[[^%]]*%]%([^%)]*" .. vim.pesc(filename) .. "[^%)]*%)")
                if has_link then
                    table.insert(backlinks, {
                        path = relative_path,
                        line = tonumber(lnum),
                        content = content,
                    })
                end
            end
        end
    end

    table.sort(backlinks, function(a, b)
        if a.path == b.path then
            return a.line < b.line
        end
        return a.path < b.path
    end)

    return backlinks
end

--- Builds a markdown tag link from a tag name.
--- @param tag_name string The tag name to format
--- @return string The formatted markdown tag link
M.build_tag_link = function(tag_name)
    -- Remove control characters (newlines, tabs, null, etc.)
    local safe_name = tag_name:gsub("[%c]", "")
    local encoded_name = M.url_encode(safe_name)
    local link_text = "#" .. safe_name
    return string.format("[%s](source/#%s.md)", link_text, encoded_name)
end

--- Converts the word under the cursor to a markdown tag link.
--- If the cursor is on a word starting with #, replaces it with a markdown link
--- in the format [#tagname](source/#tagname.md). URL-encodes the tag name in the link.
--- Returns false if cursor is already on a markdown link.
--- Operates on the current buffer and modifies the current line in place.
--- @return boolean true if conversion succeeded, false if word doesn't start with # or already on link
M.convert_word_to_tag_link = function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local col = cursor[2]

    local line = vim.api.nvim_get_current_line()
    local line_length = #line

    local function is_on_markdown_link()
        local start_pos = 1
        while true do
            local link_start, link_end = line:find("%[[^%]]*%]%([^%)]*%)", start_pos)
            if not link_start then
                return false
            end

            local link_col_start = link_start - 1
            local link_col_end = link_end - 1

            if col >= link_col_start and col <= link_col_end then
                return true
            end

            start_pos = link_end + 1
        end
    end

    if is_on_markdown_link() then
        return false
    end

    local start_col = col
    local end_col = col

    while start_col > 0 and line:sub(start_col, start_col):match("[%w%p#]") do
        start_col = start_col - 1
    end

    while end_col < line_length and line:sub(end_col + 1, end_col + 1):match("[%w%p#]") do
        end_col = end_col + 1
    end

    local word = line:sub(start_col + 1, end_col)

    if word:match("^#") then
        local tag_name = word:sub(2)
        -- Remove control characters
        tag_name = tag_name:gsub("[%c]", "")
        if tag_name == "" then
            return false
        end
        local link = M.build_tag_link(tag_name)

        local new_line = line:sub(1, start_col) .. link .. line:sub(end_col + 1)
        vim.api.nvim_set_current_line(new_line)
        return true
    end

    return false
end

--- Checks if a path is within the wiki root (prevents path traversal).
--- @param path string The path to check
--- @return boolean true if path is within wiki root, false otherwise
M.is_within_wiki_root = function(path)
    local resolved = vim.fn.resolve(path)
    local root = vim.fn.resolve(M.get_wiki_root())
    return resolved:sub(1, #root) == root
end

--- Smart function that either opens a link under cursor or converts word to tag link.
--- If cursor is over a markdown link, opens the link target in a new buffer.
--- If cursor is not over a link, converts the word under cursor to a tag link.
--- @return boolean true if action succeeded, false otherwise
M.create_tag_or_open_link = function()
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
    if link_url then
        local decoded_url = M.url_decode(link_url)
        local full_path

        if decoded_url:match("^/") then
            full_path = M.get_wiki_root() .. decoded_url
        elseif decoded_url:match("^%./") then
            full_path = M.get_wiki_root() .. "/" .. decoded_url:sub(3)
        else
            full_path = M.get_wiki_root() .. "/" .. decoded_url
        end

        if not M.is_within_wiki_root(full_path) then
            return false
        end

        if vim.fn.filereadable(full_path) == 1 then
            vim.cmd("edit " .. vim.fn.fnameescape(full_path))
            return true
        else
            local dir = vim.fn.fnamemodify(full_path, ":h")
            vim.fn.mkdir(dir, "p")

            local filename = vim.fn.fnamemodify(full_path, ":t:r")
            local file = io.open(full_path, "w")
            if file then
                file:write("# " .. filename .. "\n")
                file:close()
            end

            vim.cmd("edit " .. vim.fn.fnameescape(full_path))
            return true
        end
    end

    return M.convert_word_to_tag_link()
end

--- Finds all instances of a tag that are not links to the tag file.
--- Searches for #tagname patterns and excludes those that are markdown links.
--- @param tag_name string The tag name to search for (with # prefix, e.g. "#mytag")
--- @return table Array of unlinked tag objects, each with:
---   - path: string - relative path of the file containing the unlinked tag
---   - line: number - line number where the tag appears
---   - content: string - the line content
M.unlinked_tags = function(tag_name)
    if not tag_name or tag_name == "" then
        return {}
    end

    local lines = M.ripgrep({
        "--type=markdown",
        "--line-number",
        "--with-filename",
        tag_name,
        M.get_wiki_root(),
    })

    local unlinked = {}
    for _, line in ipairs(lines) do
        local filepath, lnum, content = line:match("^([^:]+):(%d+):(.+)$")
        if filepath and lnum and content then
            local relative_path = M.get_relative_path(filepath)
            local tag_link_pattern = "%[" .. vim.pesc(tag_name) .. "%]%([^%)]*source/"
            if not content:match(tag_link_pattern) then
                local found_plain = false
                local search_start = 1
                while not found_plain do
                    local match_start, match_end = content:find(tag_name, search_start, true)
                    if not match_start then
                        break
                    end

                    local before_ok = (match_start == 1)
                        or not content:sub(match_start - 1, match_start - 1):match("[%w%-_~]")

                    local after_ok = (match_end == #content)
                        or not content:sub(match_end + 1, match_end + 1):match("[%w%-_~]")

                    if before_ok and after_ok then
                        found_plain = true
                    else
                        search_start = match_start + 1
                    end
                end

                if found_plain then
                    table.insert(unlinked, {
                        path = relative_path,
                        line = tonumber(lnum),
                        content = content,
                    })
                end
            end
        end
    end

    table.sort(unlinked, function(a, b)
        if a.path == b.path then
            return a.line < b.line
        end
        return a.path < b.path
    end)

    return unlinked
end

--- Populates the quickfix list with unlinked occurrences of a tag.
--- If the given path is a tag file (e.g., "source/#tag1.md"), extracts the tag name
--- and finds all unlinked instances of that tag in the wiki.
--- @param filepath string The path to check (can be absolute or relative)
--- @return boolean true if quickfix list was populated, false if not a tag file
M.backlink_qfix = function(filepath)
    if not filepath or filepath == "" then
        return false
    end

    local relative_path = M.get_relative_path(filepath)
    local tag_name = relative_path:match("^source/(#[^/]+)%.md$")
    if not tag_name then
        return false
    end

    tag_name = M.url_decode(tag_name)
    local unlinked = M.unlinked_tags(tag_name)

    local qf_items = {}
    for _, item in ipairs(unlinked) do
        table.insert(qf_items, {
            filename = M.get_wiki_root() .. "/" .. item.path,
            lnum = item.line,
            text = item.content,
        })
    end

    vim.fn.setqflist(qf_items)
    vim.cmd("copen")
    return true
end

return M
