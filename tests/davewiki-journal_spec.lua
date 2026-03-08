-- Mock telescope before requiring journal module
package.loaded["telescope.pickers"] = {
    new = function(opts, config)
        return {
            find = function(self) end,
        }
    end,
}
package.loaded["telescope.finders"] = {
    new_table = function(opts)
        return {}
    end,
}
package.loaded["telescope.config"] = {
    values = {
        generic_sorter = function(opts)
            return {}
        end,
        file_previewer = function(opts)
            return {}
        end,
    },
}

-- Mock davewiki-core
package.loaded["davewiki-core"] = {
    get_journal_dir = function()
        return "/home/testuser/vimwiki/journal"
    end,
}

local journal = require("davewiki-journal")

describe("davewiki-journal", function()
    it("should have today function", function()
        assert.is_function(journal.today)
    end)

    it("should have yesterday function", function()
        assert.is_function(journal.yesterday)
    end)

    it("should have tomorrow function", function()
        assert.is_function(journal.tomorrow)
    end)

    it("should have browse function", function()
        assert.is_function(journal.browse)
    end)

    it("should have calendar function", function()
        assert.is_function(journal.calendar)
    end)

    describe("today", function()
        local original_cmd
        local original_fn
        local captured_cmd

        before_each(function()
            original_cmd = vim.cmd
            captured_cmd = {}

            vim.cmd = function(cmd_str)
                table.insert(captured_cmd, cmd_str)
            end

            original_fn = vim.fn
            vim.fn = {
                filereadable = function()
                    return 1
                end,
                mkdir = function() end,
                fnameescape = function(path)
                    return path
                end,
            }
        end)

        after_each(function()
            vim.cmd = original_cmd
            vim.fn = original_fn
        end)

        it("should open today's journal", function()
            journal.today()
            assert.is_true(#captured_cmd > 0)
            assert.matches("edit", captured_cmd[1])
        end)
    end)

    describe("yesterday", function()
        local original_cmd
        local original_fn
        local captured_cmd

        before_each(function()
            original_cmd = vim.cmd
            captured_cmd = {}

            vim.cmd = function(cmd_str)
                table.insert(captured_cmd, cmd_str)
            end

            original_fn = vim.fn
            vim.fn = {
                expand = function(path)
                    if path == "%:t" then
                        return "2024-01-15.md"
                    end
                    return path
                end,
                filereadable = function()
                    return 1
                end,
                mkdir = function() end,
                fnameescape = function(path)
                    return path
                end,
            }
        end)

        after_each(function()
            vim.cmd = original_cmd
            vim.fn = original_fn
        end)

        it("should open yesterday's journal", function()
            journal.yesterday()
            assert.is_true(#captured_cmd > 0)
            assert.matches("edit", captured_cmd[1])
        end)

        it("should handle buffer with no date", function()
            vim.fn.expand = function(path)
                if path == "%:t" then
                    return "notes.md"
                end
                return path
            end

            journal.yesterday()
            assert.is_true(#captured_cmd > 0)
        end)
    end)

    describe("tomorrow", function()
        local original_cmd
        local original_fn
        local captured_cmd

        before_each(function()
            original_cmd = vim.cmd
            captured_cmd = {}

            vim.cmd = function(cmd_str)
                table.insert(captured_cmd, cmd_str)
            end

            original_fn = vim.fn
            vim.fn = {
                expand = function(path)
                    if path == "%:t" then
                        return "2024-01-15.md"
                    end
                    return path
                end,
                filereadable = function()
                    return 1
                end,
                mkdir = function() end,
                fnameescape = function(path)
                    return path
                end,
            }
        end)

        after_each(function()
            vim.cmd = original_cmd
            vim.fn = original_fn
        end)

        it("should open tomorrow's journal", function()
            journal.tomorrow()
            assert.is_true(#captured_cmd > 0)
            assert.matches("edit", captured_cmd[1])
        end)

        it("should handle buffer with no date", function()
            vim.fn.expand = function(path)
                if path == "%:t" then
                    return "notes.md"
                end
                return path
            end

            journal.tomorrow()
            assert.is_true(#captured_cmd > 0)
        end)
    end)

    describe("browse", function()
        local original_popen
        local original_print
        local captured_print

        before_each(function()
            original_popen = io.popen
            original_print = print
            captured_print = {}

            io.popen = function()
                return nil
            end

            print = function(msg)
                table.insert(captured_print, msg)
            end
        end)

        after_each(function()
            io.popen = original_popen
            print = original_print
        end)

        it("should print message when no journal entries found", function()
            journal.browse()
            assert.is_true(#captured_print > 0)
            assert.equals("No journal entries found", captured_print[1])
        end)
    end)

    describe("calendar", function()
        local original_ui_input
        local original_cmd
        local original_fn
        local captured_input

        before_each(function()
            original_ui_input = vim.ui.input
            original_cmd = vim.cmd
            original_fn = vim.fn
            captured_input = {}

            vim.ui.input = function(opts, callback)
                table.insert(captured_input, opts)
                if opts.prompt:match("Enter date") then
                    callback("2024-01-20")
                end
            end

            vim.cmd = function() end

            vim.fn = {
                filereadable = function()
                    return 1
                end,
                mkdir = function() end,
                fnameescape = function(path)
                    return path
                end,
            }
        end)

        after_each(function()
            vim.ui.input = original_ui_input
            vim.cmd = original_cmd
            vim.fn = original_fn
        end)

        it("should prompt for date input", function()
            journal.calendar()
            assert.is_true(#captured_input > 0)
            assert.matches("Enter date", captured_input[1].prompt)
        end)

        it("should handle numeric offset input", function()
            local captured_cmd = {}
            vim.cmd = function(cmd_str)
                table.insert(captured_cmd, cmd_str)
            end

            vim.ui.input = function(opts, callback)
                callback("+1")
            end

            journal.calendar()
            assert.is_true(#captured_cmd > 0)
        end)

        it("should handle nil input gracefully", function()
            local captured_print = {}
            print = function(msg)
                table.insert(captured_print, msg)
            end

            vim.ui.input = function(opts, callback)
                callback(nil)
            end

            journal.calendar()
            assert.equals(0, #captured_print)
        end)

        it("should handle invalid date format", function()
            local captured_print = {}
            print = function(msg)
                table.insert(captured_print, msg)
            end

            vim.ui.input = function(opts, callback)
                callback("invalid")
            end

            journal.calendar()
            assert.is_true(#captured_print > 0)
            assert.matches("Invalid date format", captured_print[1])
        end)
    end)
end)
