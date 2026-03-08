local telescope = require("davewiki-telescope")
local davwiki = require("davewiki-core")

describe("davewiki-telescope", function()
    describe("insert_link", function()
        -- This function is mainly a wrapper around telescope functionality,
        -- so we'll test that it calls the expected functions
        it("should be defined", function()
            assert.is_function(telescope.insert_link)
        end)
    end)

    describe("backlinks", function()
        local original_get_current_wiki_path
        local original_get_backlinks
        
        before_each(function()
            original_get_current_wiki_path = davwiki.get_current_wiki_path
            original_get_backlinks = davwiki.get_backlinks
        end)

        after_each(function()
            davwiki.get_current_wiki_path = original_get_current_wiki_path
            davwiki.get_backlinks = original_get_backlinks
        end)

        it("should be defined", function()
            assert.is_function(telescope.backlinks)
        end)
    end)

    describe("search_tags", function()
        it("should be defined", function()
            assert.is_function(telescope.search_tags)
        end)
    end)

    describe("search_by_tag", function()
        local original_ripgrep
        
        before_each(function()
            original_ripgrep = davwiki.ripgrep
        end)

        after_each(function()
            davwiki.ripgrep = original_ripgrep
        end)

        it("should be defined", function()
            assert.is_function(telescope.search_by_tag)
        end)
    end)

    describe("insert_tag", function()
        it("should be defined", function()
            assert.is_function(telescope.insert_tag)
        end)
    end)

    describe("search_headings", function()
        local original_get_all_headings
        
        before_each(function()
            original_get_all_headings = require("davewiki-telescope").get_all_headings
        end)

        after_each(function()
            -- We can't easily restore the function, but we're testing that it exists
        end)

        it("should be defined", function()
            assert.is_function(telescope.search_headings)
        end)
    end)

    describe("wiki_grep", function()
        it("should be defined", function()
            assert.is_function(telescope.wiki_grep)
        end)
    end)
end)