local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local wiki = require("davewiki-core")

local M = {}

-- ==================================================================
-- HEADING SEARCH
-- ==================================================================

local function get_all_headings()
    local lines = wiki.ripgrep({
        "^#{1,6} .+",
        "--line-number",
        "--with-filename",
        "--type=markdown",
        wiki.get_wiki_root(),
    })

    local results = {}
    for _, line in ipairs(lines) do
        local filepath, lnum, content = line:match("^([^:]+):(%d+):(.+)$")
        if filepath and lnum and content then
            local relative = wiki.get_relative_path(filepath)
            local heading = content:match("^(#+%s+.+)$")
            if heading then
                table.insert(results, {
                    path = relative,
                    line = tonumber(lnum),
                    heading = heading,
                })
            end
        end
    end

    return results
end

-- ==================================================================
-- TELESCOPE PICKERS
-- ==================================================================

M.backlinks = function(opts)
    opts = opts or {}

    local current_path = wiki.get_current_wiki_path()
    local backlinks = wiki.get_backlinks(current_path)

    if #backlinks == 0 then
        print("No backlinks found")
        return
    end

    pickers
        .new(opts, {
            prompt_title = "Backlinks to " .. current_path,
            finder = finders.new_table({
                results = backlinks,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.path .. ":" .. entry.line .. " - " .. entry.content,
                        ordinal = entry.path .. " " .. entry.content,
                        filename = vim.fn.expand(wiki.get_wiki_root() .. "/" .. entry.path),
                        lnum = entry.line,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
            previewer = conf.grep_previewer(opts),
        })
        :find()
end

M.search_tags = function(opts)
    opts = opts or {}

    local tags = wiki.find_tags()

    if #tags == 0 then
        print("No tags found")
        return
    end

    pickers
        .new(opts, {
            prompt_title = "Search Tags",
            finder = finders.new_table({
                results = tags,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = "#" .. entry.tag .. " (" .. entry.count .. ")",
                        ordinal = entry.tag,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)

                    if selection then
                        M.search_by_tag(selection.value.tag)
                    end
                end)
                return true
            end,
        })
        :find()
end

M.search_by_tag = function(tag)
    local safe_tag = tag:gsub("[^%w%-_]", "")
    local lines = wiki.ripgrep({
        "#" .. safe_tag .. "\\b",
        "--files-with-matches",
        "--type=markdown",
        wiki.get_wiki_root(),
    })

    local results = {}
    for _, filepath in ipairs(lines) do
        local relative = wiki.get_relative_path(filepath)
        local heading = wiki.extract_heading(filepath)
        table.insert(results, {
            path = relative,
            title = heading or vim.fn.fnamemodify(relative, ":t:r"),
        })
    end

    if #results == 0 then
        print("No files with tag #" .. safe_tag)
        return
    end

    pickers
        .new({}, {
            prompt_title = "Files with #" .. safe_tag,
            finder = finders.new_table({
                results = results,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.title .. " (" .. entry.path .. ")",
                        ordinal = entry.title .. " " .. entry.path,
                        filename = vim.fn.expand(wiki.get_wiki_root() .. "/" .. entry.path),
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            previewer = conf.file_previewer({}),
        })
        :find()
end

M.insert_tag = function(opts)
    opts = opts or {}

    local tags = wiki.find_tags()

    if #tags == 0 then
        print("No tags found")
        return
    end

    pickers
        .new(opts, {
            prompt_title = "Insert Tag",
            finder = finders.new_table({
                results = tags,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = "#" .. entry.tag .. " (" .. entry.count .. ")",
                        ordinal = entry.tag,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)

                    if selection then
                        local link = wiki.build_tag_link(selection.value.tag)
                        vim.api.nvim_put({ link }, "c", true, true)
                    end
                end)
                return true
            end,
        })
        :find()
end

M.search_headings = function(opts)
    opts = opts or {}

    local headings = get_all_headings()

    if #headings == 0 then
        print("No headings found")
        return
    end

    pickers
        .new(opts, {
            prompt_title = "Search Headings",
            finder = finders.new_table({
                results = headings,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.heading .. " (" .. entry.path .. ":" .. entry.line .. ")",
                        ordinal = entry.heading .. " " .. entry.path,
                        filename = vim.fn.expand(wiki.get_wiki_root() .. "/" .. entry.path),
                        lnum = entry.line,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
            previewer = conf.grep_previewer(opts),
        })
        :find()
end

return M
