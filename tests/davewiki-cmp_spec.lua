describe("davewiki-cmp", function()
    local original_buf_get_name
    local original_fn_expand
    local original_bo
    local test_wiki_root

    before_each(function()
        package.loaded["davewiki-cmp"] = nil
        package.loaded["davewiki-core"] = nil
        package.loaded["cmp"] = nil

        original_buf_get_name = vim.api.nvim_buf_get_name
        original_fn_expand = vim.fn.expand
        original_bo = vim.bo

        test_wiki_root = "/home/testuser/vimwiki"

        vim.fn.expand = function(path)
            if path == "~/vimwiki" or path == vim.g.davewiki_root then
                return test_wiki_root
            end
            return path
        end

        _G.cmp = {
            register_source = function(name, src)
                assert.equals("wiki_tags", name)
                return src
            end,
            lsp = {
                CompletionItemKind = {
                    Text = 1,
                },
            },
        }
        package.loaded["cmp"] = _G.cmp

        _G.davewiki_core = {
            get_wiki_root = function()
                return "~/vimwiki"
            end,
            find_tags = function()
                return {}
            end,
        }
        package.loaded["davewiki-core"] = _G.davewiki_core
    end)

    after_each(function()
        vim.api.nvim_buf_get_name = original_buf_get_name
        vim.fn.expand = original_fn_expand
        vim.bo = original_bo
        _G.cmp = nil
        _G.davewiki_core = nil
    end)

    describe("setup", function()
        it("should register source with cmp", function()
            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()
            assert.is_table(source)
        end)

        it("should return source object", function()
            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()
            assert.is_function(source.new)
            assert.is_function(source.get_keyword_pattern)
            assert.is_function(source.is_available)
            assert.is_function(source.complete)
        end)
    end)

    describe("source.new", function()
        it("should create a new source instance", function()
            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()
            local instance = source.new()
            assert.is_table(instance)
        end)
    end)

    describe("source.get_keyword_pattern", function()
        it("should return pattern matching hashtags with word characters", function()
            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()
            local pattern = source.get_keyword_pattern()
            assert.equals([[\#[a-zA-Z0-9_-]+]], pattern)
        end)
    end)

    describe("source.is_available", function()
        it("should return true for markdown files in wiki root", function()
            vim.api.nvim_buf_get_name = function()
                return test_wiki_root .. "/notes/test.md"
            end
            vim.bo = { filetype = "markdown" }

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()
            assert.is_true(source.is_available())
        end)

        it("should return false for non-markdown files", function()
            vim.api.nvim_buf_get_name = function()
                return test_wiki_root .. "/notes/test.md"
            end
            vim.bo = { filetype = "lua" }

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()
            assert.is_false(source.is_available())
        end)

        it("should return false for files outside wiki root", function()
            vim.api.nvim_buf_get_name = function()
                return "/other/path/test.md"
            end
            vim.bo = { filetype = "markdown" }

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()
            assert.is_false(source.is_available())
        end)

        it("should return false for non-markdown files outside wiki root", function()
            vim.api.nvim_buf_get_name = function()
                return "/other/path/test.lua"
            end
            vim.bo = { filetype = "lua" }

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()
            assert.is_false(source.is_available())
        end)
    end)

    describe("source.complete", function()
        it("should return empty items when input does not start with #", function()
            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()

            local params = {
                context = {
                    cursor_before_line = "hello world",
                },
                offset = 0,
            }

            local captured_items
            local callback = function(result)
                captured_items = result
            end

            source.complete(nil, params, callback)
            assert.is_table(captured_items)
            assert.equals(0, #captured_items.items)
            assert.is_false(captured_items.isIncomplete)
        end)

        it("should return completion items for tags", function()
            _G.davewiki_core.find_tags = function()
                return {
                    { tag = "test", count = 5, files = {} },
                    { tag = "my-tag", count = 3, files = {} },
                }
            end
            package.loaded["davewiki-core"] = _G.davewiki_core

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()

            local params = {
                context = {
                    cursor_before_line = "#te",
                },
                offset = 0,
            }

            local captured_items
            local callback = function(result)
                captured_items = result
            end

            source.complete(nil, params, callback)
            assert.is_table(captured_items)
            assert.equals(2, #captured_items.items)
            assert.equals("#test", captured_items.items[1].label)
            assert.equals("#my-tag", captured_items.items[2].label)
        end)

        it("should include tag count in documentation", function()
            _G.davewiki_core.find_tags = function()
                return {
                    { tag = "important", count = 10, files = {} },
                }
            end
            package.loaded["davewiki-core"] = _G.davewiki_core

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()

            local params = {
                context = {
                    cursor_before_line = "#imp",
                },
                offset = 0,
            }

            local captured_items
            local callback = function(result)
                captured_items = result
            end

            source.complete(nil, params, callback)
            assert.equals("Used 10 times", captured_items.items[1].documentation)
        end)

        it("should set completion item kind to Text", function()
            _G.davewiki_core.find_tags = function()
                return {
                    { tag = "test", count = 1, files = {} },
                }
            end
            package.loaded["davewiki-core"] = _G.davewiki_core

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()

            local params = {
                context = {
                    cursor_before_line = "#t",
                },
                offset = 0,
            }

            local captured_items
            local callback = function(result)
                captured_items = result
            end

            source.complete(nil, params, callback)
            assert.equals(1, captured_items.items[1].kind)
        end)

        it("should set insertText to tag name without #", function()
            _G.davewiki_core.find_tags = function()
                return {
                    { tag = "my-tag", count = 2, files = {} },
                }
            end
            package.loaded["davewiki-core"] = _G.davewiki_core

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()

            local params = {
                context = {
                    cursor_before_line = "#my",
                },
                offset = 0,
            }

            local captured_items
            local callback = function(result)
                captured_items = result
            end

            source.complete(nil, params, callback)
            assert.equals("my-tag", captured_items.items[1].insertText)
        end)

        it("should return empty items when no tags found", function()
            _G.davewiki_core.find_tags = function()
                return {}
            end
            package.loaded["davewiki-core"] = _G.davewiki_core

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()

            local params = {
                context = {
                    cursor_before_line = "#xyz",
                },
                offset = 0,
            }

            local captured_items
            local callback = function(result)
                captured_items = result
            end

            source.complete(nil, params, callback)
            assert.is_table(captured_items)
            assert.equals(0, #captured_items.items)
        end)

        it("should extract input from offset position", function()
            _G.davewiki_core.find_tags = function()
                return {
                    { tag = "test", count = 1, files = {} },
                }
            end
            package.loaded["davewiki-core"] = _G.davewiki_core

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()

            local params = {
                context = {
                    cursor_before_line = "text #te",
                },
                offset = 6,
            }

            local captured_items
            local callback = function(result)
                captured_items = result
            end

            source.complete(nil, params, callback)
            assert.is_table(captured_items)
            assert.equals(1, #captured_items.items)
        end)

        it("should set isIncomplete to false", function()
            _G.davewiki_core.find_tags = function()
                return {
                    { tag = "test", count = 1, files = {} },
                }
            end
            package.loaded["davewiki-core"] = _G.davewiki_core

            local cmp_module = require("davewiki-cmp")
            local source = cmp_module.setup()

            local params = {
                context = {
                    cursor_before_line = "#t",
                },
                offset = 0,
            }

            local captured_items
            local callback = function(result)
                captured_items = result
            end

            source.complete(nil, params, callback)
            assert.is_false(captured_items.isIncomplete)
        end)
    end)
end)
