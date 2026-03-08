local davwiki = require("davewiki-core")

describe("davewiki-core", function()
    local original_buf_get_name
    local original_get_current_buf
    local original_buf_get_lines
    local original_io_open

    before_each(function()
        original_buf_get_name = vim.api.nvim_buf_get_name
        original_get_current_buf = vim.api.nvim_get_current_buf
        original_buf_get_lines = vim.api.nvim_buf_get_lines

        vim.api.nvim_buf_get_name = function()
            return "/home/testuser/vimwiki/notes/test.md"
        end
        vim.api.nvim_get_current_buf = function()
            return 1
        end
        vim.api.nvim_buf_get_lines = function(bufnr, start, ending, strict_indexing)
            return {
                "# Hello World",
                "Some content with #tag1 and #another-tag",
                "More content #tag2",
            }
        end
    end)

    after_each(function()
        vim.api.nvim_buf_get_name = original_buf_get_name
        vim.api.nvim_get_current_buf = original_get_current_buf
        vim.api.nvim_buf_get_lines = original_buf_get_lines
    end)

    describe("get_current_wiki_path", function()
        it("should return relative path of current buffer", function()
            local path = davwiki.get_current_wiki_path()
            assert.matches("notes/test.md", path)
        end)
    end)

    describe("extract_heading", function()
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

    describe("get_buffer_tags", function()
        it("should extract tags from current buffer", function()
            local tags = davwiki.get_buffer_tags()
            assert.is_table(tags)
            assert.equals(3, #tags)
        end)

        it("should return tags sorted by count descending", function()
            vim.api.nvim_buf_get_lines = function(bufnr, start, ending, strict_indexing)
                return {
                    "# Hello World",
                    "Some content with #tag1 and #tag1 and #tag1",
                    "More content #tag2",
                }
            end
            local tags = davwiki.get_buffer_tags()
            assert.equals("tag1", tags[1].tag)
            assert.equals(3, tags[1].count)
        end)

        it("should return tags sorted alphabetically when counts equal", function()
            local tags = davwiki.get_buffer_tags()
            local tag_names = {}
            for _, t in ipairs(tags) do
                table.insert(tag_names, t.tag)
            end
            local expected = { "another-tag", "tag1", "tag2" }
            assert.same(expected, tag_names)
        end)
    end)

    describe("get_all_tags", function()
        it("should return sorted list of tags", function()
            local tags = davwiki.get_all_tags()
            assert.is_table(tags)
        end)
    end)
end)
