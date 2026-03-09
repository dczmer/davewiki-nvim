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
            assert.equals("source/#test-tag.md", tags[1].files[1])
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
            assert.equals("source/#My Tag.md", tags[1].files[1])
        end)
    end)

    describe("find_tag_links", function()
        local original_ripgrep
        local original_fn_expand
        local test_wiki_root

        before_each(function()
            original_ripgrep = davwiki.ripgrep
            original_fn_expand = vim.fn.expand
            test_wiki_root = "/home/testuser/vimwiki"
            vim.fn.expand = function(path)
                if path == "~/vimwiki" or path == vim.g.davewiki_root then
                    return test_wiki_root
                end
                if path:sub(1, #test_wiki_root) == test_wiki_root then
                    return path
                end
                return path
            end
        end)

        after_each(function()
            davwiki.ripgrep = original_ripgrep
            vim.fn.expand = original_fn_expand
        end)

        it("should return empty table when no tag links found", function()
            davwiki.ripgrep = function()
                return {}
            end
            local files = davwiki.find_tag_links()
            assert.is_table(files)
            assert.equals(0, #files)
        end)

        it("should find tag links from markdown files", function()
            davwiki.ripgrep = function()
                return {
                    test_wiki_root .. "/notes/test1.md:[#My Tag](source/#My%20Tag.md)",
                    test_wiki_root .. "/notes/test2.md:[#Another](source/#Another.md)",
                }
            end
            local files = davwiki.find_tag_links()
            assert.is_table(files)
            assert.equals(2, #files)
        end)

        it("should include tags in file results", function()
            davwiki.ripgrep = function()
                return {
                    test_wiki_root .. "/notes/test.md:[#My Tag](source/#My%20Tag.md)",
                }
            end
            local files = davwiki.find_tag_links()
            assert.equals("notes/test.md", files[1].filepath)
            assert.is_table(files[1].tags)
            assert.equals("#My Tag", files[1].tags[1])
        end)

        it("should deduplicate tags within same file", function()
            davwiki.ripgrep = function()
                return {
                    test_wiki_root .. "/notes/test.md:[#My Tag](source/#My%20Tag.md)",
                    test_wiki_root .. "/notes/test.md:[#My Tag](source/#My%20Tag.md)",
                }
            end
            local files = davwiki.find_tag_links()
            assert.equals(1, #files[1].tags)
            assert.equals(1, files[1].count)
        end)

        it("should filter results by specific tag name", function()
            davwiki.ripgrep = function(args)
                assert.is_true(#args > 0)
                return {
                    test_wiki_root .. "/notes/test1.md:[#My Tag](source/#My%20Tag.md)",
                    test_wiki_root .. "/notes/test2.md:[#My Tag](source/#Another.md)",
                    test_wiki_root .. "/notes/test3.md:[#Other Tag](source/#Other.md)",
                }
            end
            local files = davwiki.find_tag_links("My Tag")
            assert.equals(2, #files)
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

    describe("follow_tag_link", function()
        local original_win_get_cursor
        local original_buf_get_lines
        local original_cmd
        local original_fn
        local original_notify
        local test_wiki_root

        before_each(function()
            original_win_get_cursor = vim.api.nvim_win_get_cursor
            original_buf_get_lines = vim.api.nvim_buf_get_lines
            original_cmd = vim.cmd
            original_fn = vim.fn
            original_notify = vim.notify
            test_wiki_root = "/home/testuser/vimwiki"

            vim.fn.expand = function(path)
                if path == "~/vimwiki" or path == vim.g.davewiki_root then
                    return test_wiki_root
                end
                if path:sub(1, #test_wiki_root) == test_wiki_root then
                    return path
                end
                return path
            end
        end)

        after_each(function()
            vim.api.nvim_win_get_cursor = original_win_get_cursor
            vim.api.nvim_buf_get_lines = original_buf_get_lines
            vim.cmd = original_cmd
            vim.fn = original_fn
            vim.notify = original_notify
        end)

        it("should return false when cursor is not on a link", function()
            vim.api.nvim_win_get_cursor = function()
                return { 1, 0 }
            end
            vim.api.nvim_buf_get_lines = function()
                return { "no link here" }
            end

            local result = davwiki.follow_tag_link()
            assert.is_false(result)
        end)

        it("should return false when link is not a tag link", function()
            vim.api.nvim_win_get_cursor = function()
                return { 1, 5 }
            end
            vim.api.nvim_buf_get_lines = function()
                return { "text [link](other.md) more" }
            end

            local result = davwiki.follow_tag_link()
            assert.is_false(result)
        end)

        it("should open tag file when cursor is on tag link", function()
            local captured_cmd = {}
            vim.api.nvim_win_get_cursor = function()
                return { 1, 5 }
            end
            vim.api.nvim_buf_get_lines = function()
                return { "text [#tag](source/#tag.md) more" }
            end
            vim.cmd = function(cmd_str)
                table.insert(captured_cmd, cmd_str)
            end
            vim.fn.filereadable = function()
                return 1
            end
            vim.fn.fnameescape = function(path)
                return path
            end

            local result = davwiki.follow_tag_link()
            assert.is_true(result)
            assert.is_true(#captured_cmd > 0)
            assert.matches("edit", captured_cmd[1])
        end)

        it("should handle URL-encoded tag names", function()
            local captured_cmd = {}
            vim.api.nvim_win_get_cursor = function()
                return { 1, 5 }
            end
            vim.api.nvim_buf_get_lines = function()
                return { "text [#my tag](source/#my%20tag.md) more" }
            end
            vim.cmd = function(cmd_str)
                table.insert(captured_cmd, cmd_str)
            end
            vim.fn.filereadable = function()
                return 1
            end
            vim.fn.fnameescape = function(path)
                return path
            end

            local result = davwiki.follow_tag_link()
            assert.is_true(result)
        end)

        it("should create tag file when it does not exist", function()
            local captured_cmd = {}
            local captured_mkdir = {}
            local captured_file_content = {}

            vim.api.nvim_win_get_cursor = function()
                return { 1, 5 }
            end
            vim.api.nvim_buf_get_lines = function()
                return { "text [#tag](source/#tag.md) more" }
            end
            vim.cmd = function(cmd_str)
                table.insert(captured_cmd, cmd_str)
            end
            vim.fn.filereadable = function()
                return 0
            end
            vim.fn.fnamemodify = function(path, modifier)
                if modifier == ":h" then
                    return path:gsub("/[^/]+$", "")
                end
                return path
            end
            vim.fn.mkdir = function(dir, flags)
                table.insert(captured_mkdir, dir)
            end
            vim.fn.fnameescape = function(path)
                return path
            end

            local original_io_open = io.open
            io.open = function(path, mode)
                if mode == "w" then
                    local mock_file = {
                        write = function(self, content)
                            table.insert(captured_file_content, content)
                        end,
                        close = function() end,
                    }
                    return mock_file
                end
                return nil
            end

            local result = davwiki.follow_tag_link()
            assert.is_true(result)
            assert.is_true(#captured_cmd > 0)
            assert.is_true(#captured_mkdir > 0)
            assert.is_true(#captured_file_content > 0)
            assert.matches("# tag", captured_file_content[1])

            io.open = original_io_open
        end)

        it("should handle ./source/ path prefix", function()
            local captured_cmd = {}
            vim.api.nvim_win_get_cursor = function()
                return { 1, 5 }
            end
            vim.api.nvim_buf_get_lines = function()
                return { "text [#tag](./source/#tag.md) more" }
            end
            vim.cmd = function(cmd_str)
                table.insert(captured_cmd, cmd_str)
            end
            vim.fn.filereadable = function()
                return 1
            end
            vim.fn.fnameescape = function(path)
                return path
            end

            local result = davwiki.follow_tag_link()
            assert.is_true(result)
        end)
    end)

    describe("get_backlinks", function()
        local original_ripgrep
        local original_fn_expand
        local original_fn_fnamemodify
        local original_fn_shellescape
        local test_wiki_root

        before_each(function()
            original_ripgrep = davwiki.ripgrep
            original_fn_expand = vim.fn.expand
            original_fn_fnamemodify = vim.fn.fnamemodify
            original_fn_shellescape = vim.fn.shellescape
            test_wiki_root = "/home/testuser/vimwiki"
            vim.fn.expand = function(path)
                if path == "~/vimwiki" or path == vim.g.davewiki_root then
                    return test_wiki_root
                end
                if path:sub(1, #test_wiki_root) == test_wiki_root then
                    return path
                end
                return path
            end
            vim.fn.fnamemodify = function(path, modifier)
                if modifier == ":t" then
                    return path:match("[^/]+$") or path
                end
                return path
            end
            vim.fn.shellescape = function(s)
                return "'" .. s .. "'"
            end
        end)

        after_each(function()
            davwiki.ripgrep = original_ripgrep
            vim.fn.expand = original_fn_expand
            vim.fn.fnamemodify = original_fn_fnamemodify
            vim.fn.shellescape = original_fn_shellescape
        end)

        it("should return empty table for nil target_path", function()
            local backlinks = davwiki.get_backlinks(nil)
            assert.is_table(backlinks)
            assert.equals(0, #backlinks)
        end)

        it("should return empty table for empty target_path", function()
            local backlinks = davwiki.get_backlinks("")
            assert.is_table(backlinks)
            assert.equals(0, #backlinks)
        end)

        it("should return empty table when no backlinks found", function()
            davwiki.ripgrep = function()
                return {}
            end
            local backlinks = davwiki.get_backlinks("notes/target.md")
            assert.is_table(backlinks)
            assert.equals(0, #backlinks)
        end)

        it("should find backlinks with standard markdown links", function()
            davwiki.ripgrep = function()
                return {
                    test_wiki_root .. "/notes/source.md:10:See [link](notes/target.md) for more",
                }
            end
            local backlinks = davwiki.get_backlinks("notes/target.md")
            assert.equals(1, #backlinks)
            assert.equals("notes/source.md", backlinks[1].path)
            assert.equals(10, backlinks[1].line)
            assert.matches("link", backlinks[1].content)
        end)

        it("should find backlinks with wiki-style links", function()
            davwiki.ripgrep = function()
                return {
                    test_wiki_root .. "/notes/source.md:5:Check [[notes/target.md]] here",
                }
            end
            local backlinks = davwiki.get_backlinks("notes/target.md")
            assert.equals(1, #backlinks)
            assert.equals("notes/source.md", backlinks[1].path)
        end)

        it("should find backlinks with filename-only links", function()
            davwiki.ripgrep = function()
                return {
                    test_wiki_root .. "/notes/source.md:3:See [target](target.md)",
                }
            end
            local backlinks = davwiki.get_backlinks("notes/target.md")
            assert.equals(1, #backlinks)
        end)

        it("should exclude self-references", function()
            davwiki.ripgrep = function()
                return {
                    test_wiki_root .. "/notes/target.md:1:See [link](notes/target.md)",
                }
            end
            local backlinks = davwiki.get_backlinks("notes/target.md")
            assert.equals(0, #backlinks)
        end)

        it("should sort backlinks by path then line number", function()
            davwiki.ripgrep = function()
                return {
                    test_wiki_root .. "/notes/b.md:5:[link](notes/target.md)",
                    test_wiki_root .. "/notes/a.md:10:[link](notes/target.md)",
                    test_wiki_root .. "/notes/a.md:5:[link](notes/target.md)",
                }
            end
            local backlinks = davwiki.get_backlinks("notes/target.md")
            assert.equals(3, #backlinks)
            assert.equals("notes/a.md", backlinks[1].path)
            assert.equals(5, backlinks[1].line)
            assert.equals("notes/a.md", backlinks[2].path)
            assert.equals(10, backlinks[2].line)
            assert.equals("notes/b.md", backlinks[3].path)
        end)

        it("should not match plain text occurrences", function()
            davwiki.ripgrep = function()
                return {
                    test_wiki_root .. "/notes/source.md:1:notes/target.md is a path",
                }
            end
            local backlinks = davwiki.get_backlinks("notes/target.md")
            assert.equals(0, #backlinks)
        end)
    end)
end)
