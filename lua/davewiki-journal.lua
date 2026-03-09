local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local wiki = require("davewiki-core")

-- ==================================================================
-- MODULE
-- ==================================================================
local M = {}

-- Daily note template
local TEMPLATE = [[# %s - %s

## Tasks
- [ ]

## Notes

]]

-- ==================================================================
-- DATE UTILITIES
-- ==================================================================

local function format_date(time)
    return os.date("%Y-%m-%d", time)
end

local function get_day_name(time)
    return os.date("%A", time)
end

local function parse_date(filename)
    local year, month, day = filename:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if not year then
        return nil
    end

    return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = 12,
    })
end

local function add_days(time, days)
    return time + (days * 24 * 60 * 60)
end

local function get_buffer_date()
    local filename = vim.fn.expand("%:t")
    return parse_date(filename)
end

-- ==================================================================
-- FILE OPERATIONS
-- ==================================================================

local function get_journal_path(time)
    local date = format_date(time)
    return wiki.get_journal_dir() .. "/" .. date .. ".md"
end

local function journal_exists(time)
    local filepath = get_journal_path(time)
    return vim.fn.filereadable(filepath) == 1
end

local function create_journal(time)
    local filepath = get_journal_path(time)
    local date = format_date(time)
    local day = get_day_name(time)

    vim.fn.mkdir(wiki.get_journal_dir(), "p")

    local content = string.format(TEMPLATE, date, day)
    local file = io.open(filepath, "w")
    if file then
        file:write(content)
        file:close()
    end

    return filepath
end

local function open_journal(time)
    local filepath = get_journal_path(time)

    if not journal_exists(time) then
        filepath = create_journal(time)
    end

    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
end

-- ==================================================================
-- JOURNAL NAVIGATION
-- ==================================================================

M.today = function()
    open_journal(os.time())
end

M.yesterday = function()
    local current = get_buffer_date()
    if current then
        open_journal(add_days(current, -1))
    else
        open_journal(add_days(os.time(), -1))
    end
end

M.tomorrow = function()
    local current = get_buffer_date()
    if current then
        open_journal(add_days(current, 1))
    else
        open_journal(add_days(os.time(), 1))
    end
end

-- ==================================================================
-- JOURNAL BROWSER
-- ==================================================================

local function get_journal_entries()
    local entries = {}
    local files = vim.fn.glob(wiki.get_journal_dir() .. "/*.md", true, true)

    for _, filepath in ipairs(files) do
        local filename = vim.fn.fnamemodify(filepath, ":t")
        local time = parse_date(filename)
        if time then
            table.insert(entries, {
                filepath = filepath,
                filename = filename,
                date = format_date(time),
                day = get_day_name(time),
                time = time,
            })
        end
    end

    table.sort(entries, function(a, b)
        return a.time > b.time
    end)

    return entries
end

M.browse = function(opts)
    opts = opts or {}

    local entries = get_journal_entries()

    if #entries == 0 then
        print("No journal entries found")
        return
    end

    pickers
        .new(opts, {
            prompt_title = "Journal Entries",
            finder = finders.new_table({
                results = entries,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.date .. " - " .. entry.day,
                        ordinal = entry.date,
                        filename = entry.filepath,
                    }
                end,
            }),
            sorter = conf.generic_sorter(opts),
            previewer = conf.file_previewer(opts),
        })
        :find()
end

-- ==================================================================
-- CALENDAR INTEGRATION
-- ==================================================================

M.calendar = function()
    vim.ui.input({
        prompt = "Enter date (YYYY-MM-DD) or offset (+1, -1, etc): ",
        default = format_date(os.time()),
    }, function(input)
        if not input then
            return
        end

        local time
        if input:match("^[+-]?%d+$") then
            local offset = tonumber(input)
            time = add_days(os.time(), offset)
        else
            local year, month, day = input:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
            if year then
                time = os.time({
                    year = tonumber(year),
                    month = tonumber(month),
                    day = tonumber(day),
                    hour = 12,
                })
            end
        end

        if time then
            open_journal(time)
        else
            print("Invalid date format. Use YYYY-MM-DD or offset (+1, -1)")
        end
    end)
end

return M
