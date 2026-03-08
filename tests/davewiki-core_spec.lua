local davwiki = require("davewiki-core")

describe("davewiki-core", function()
    describe("get_current_wiki_path", function()
        local original_buf_get_name

        before_each(function()
            original_buf_get_name = vim.api.nvim_buf_get_name
            vim.api.nvim_buf_get_name = function()
                return "/home/testuser/vimwiki/notes/test.md"
            end
        end)

        after_each(function()
            vim.api.nvim_buf_get_name = original_buf_get_name
        end)

        it("should return relative path of current buffer", function()
            local path = davwiki.get_current_wiki_path()
            assert.matches("notes/test.md", path)
        end)
    end)

    describe("extract_heading", function()
        local original_io_open

        before_each(function()
            original_io_open = io.open
        end)

        after_each(function()
            io.open = original_io_open
        end)

        it("should extract first heading from file", function()
            io.open = function(path, mode)
                local mock_file = {}
                mock_file.lines = function()
                    return coroutine.wrap(function()
                        coroutine.yield("# My Heading")
                        coroutine.yield("Some content")
                    end)
                end
                mock_file.close = function() end
                return mock_file
            end

            local heading = davwiki.extract_heading("/test/file.md")
            assert.equals("My Heading", heading)
        end)

        it("should return nil when file has no heading", function()
            io.open = function(path, mode)
                local mock_file = {}
                mock_file.lines = function()
                    return coroutine.wrap(function()
                        coroutine.yield("Just some content")
                        coroutine.yield("No heading here")
                    end)
                end
                mock_file.close = function() end
                return mock_file
            end

            local heading = davwiki.extract_heading("/test/file.md")
            assert.is_nil(heading)
        end)

        it("should return nil for non-existent file", function()
            io.open = function(path, mode)
                return nil
            end

            local heading = davwiki.extract_heading("/nonexistent/file.md")
            assert.is_nil(heading)
        end)
    end)

    describe("ripgrep", function()
        it("should return empty table on popen failure", function()
            local results = davwiki.ripgrep({})
            assert.is_table(results)
            assert.equals(0, #results)
        end)

        it("should return results from ripgrep command", function()
            local results = davwiki.ripgrep({ "-e", "test", "." })
            assert.is_table(results)
        end)
    end)

    describe("url_encode", function()
        it("should URL encode spaces", function()
            local encoded = davwiki.url_encode("my notes")
            assert.equals("my%20notes", encoded)
        end)

        it("should not encode alphanumeric characters", function()
            local encoded = davwiki.url_encode("hello world")
            assert.equals("hello%20world", encoded)
        end)

        it("should handle special characters", function()
            local encoded = davwiki.url_encode("file(1).md")
            assert.equals("file%281%29%2Emd", encoded)
        end)
    end)

    describe("url_decode", function()
        it("should URL decode spaces", function()
            local decoded = davwiki.url_decode("my%20notes")
            assert.equals("my notes", decoded)
        end)

        it("should decode multiple encoded characters", function()
            local decoded = davwiki.url_decode("hello%20world%21")
            assert.equals("hello world!", decoded)
        end)
    end)

    describe("find_tags", function()
        local original_ripgrep

        before_each(function()
            original_ripgrep = davwiki.ripgrep
        end)

        after_each(function()
            davwiki.ripgrep = original_ripgrep
        end)

        it("should return empty table when no tags found", function()
            davwiki.ripgrep = function()
                return {}
            end
            local tags = davwiki.find_tags()
            assert.is_table(tags)
            assert.equals(0, #tags)
        end)

        it("should find tags from markdown links", function()
            davwiki.ripgrep = function()
                return {
                    "[#My Tag](source/#My%20Tag.md)",
                    "[#Another](source/#Another.md)",
                }
            end
            local tags = davwiki.find_tags()
            assert.is_table(tags)
            assert.equals(2, #tags)
        end)

        it("should find tags with ./source/ path prefix", function()
            davwiki.ripgrep = function()
                return {
                    "[#test-tag](./source/#test-tag.md)",
                }
            end
            local tags = davwiki.find_tags()
            assert.is_table(tags)
            assert.equals(1, #tags)
            assert.equals("test-tag", tags[1].tag)
            assert.equals("#test-tag.md", tags[1].files[1])
        end)

        it("should include files in results", function()
            davwiki.ripgrep = function()
                return {
                    "[#My Tag](source/#My%20Tag.md)",
                }
            end
            local tags = davwiki.find_tags()
            assert.equals("My Tag", tags[1].tag)
            assert.is_table(tags[1].files)
            assert.equals("#My Tag.md", tags[1].files[1])
        end)
    end)

    describe("convert_word_to_tag_link", function()
        local original_win_get_cursor
        local original_get_current_line
        local original_set_current_line

        before_each(function()
            original_win_get_cursor = vim.api.nvim_win_get_cursor
            original_get_current_line = vim.api.nvim_get_current_line
            original_set_current_line = vim.api.nvim_set_current_line
        end)

        after_each(function()
            vim.api.nvim_win_get_cursor = original_win_get_cursor
            vim.api.nvim_get_current_line = original_get_current_line
            vim.api.nvim_set_current_line = original_set_current_line
        end)

        it("should return false when word does not start with #", function()
            vim.api.nvim_win_get_cursor = function()
                return { 1, 2 }
            end
            vim.api.nvim_get_current_line = function()
                return "hello world"
            end
            vim.api.nvim_set_current_line = function() end

            local result = davwiki.convert_word_to_tag_link()
            assert.is_false(result)
        end)

        it("should convert tag to markdown link", function()
            vim.api.nvim_win_get_cursor = function()
                return { 1, 1 }
            end
            vim.api.nvim_get_current_line = function()
                return "#mytag"
            end

            local new_line
            vim.api.nvim_set_current_line = function(line)
                new_line = line
            end

            local result = davwiki.convert_word_to_tag_link()
            assert.is_true(result)
            assert.equals("[#mytag](source/#mytag.md)", new_line)
        end)

        it("should URL encode tag names with hyphens", function()
            vim.api.nvim_win_get_cursor = function()
                return { 1, 1 }
            end
            vim.api.nvim_get_current_line = function()
                return "#dave-is-cool"
            end

            local new_line
            vim.api.nvim_set_current_line = function(line)
                new_line = line
            end

            local result = davwiki.convert_word_to_tag_link()
            assert.is_true(result)
            assert.equals("[#dave-is-cool](source/#dave-is-cool.md)", new_line)
        end)

        it("should handle tag at end of line", function()
            vim.api.nvim_win_get_cursor = function()
                return { 1, 5 }
            end
            vim.api.nvim_get_current_line = function()
                return "text #tag"
            end

            local new_line
            vim.api.nvim_set_current_line = function(line)
                new_line = line
            end

            local result = davwiki.convert_word_to_tag_link()
            assert.is_true(result)
            assert.equals("text [#tag](source/#tag.md)", new_line)
        end)
    end)
end)
