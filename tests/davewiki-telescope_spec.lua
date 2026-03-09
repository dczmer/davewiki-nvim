local telescope = require("davewiki-telescope")
local davwiki = require("davewiki-core")

describe("davewiki-telescope", function()
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
        it("should be defined", function()
            assert.is_function(telescope.search_headings)
        end)
    end)
end)
