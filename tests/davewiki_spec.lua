package.path = package.path .. ";./plugin/?.lua"
local davwiki = require("davewiki")

describe("davewiki plugin", function()
    it("should have a setup function", function()
        assert.is_function(davwiki.setup)
    end)

    it("should accept configuration options", function()
        local config = {
            root = "/test/path",
        }
        local result = davwiki.setup(config)
        assert.is_table(result)
    end)

    it("should handle empty config", function()
        local result = davwiki.setup()
        assert.is_table(result)
    end)

    it("should sanitize shell metacharacters from wiki_root", function()
        davwiki.setup({
            wiki_root = "~/wiki; rm -rf ~ #",
        })
        assert.equals("~/wiki rm -rf ~ ", vim.g.davewiki_root)
    end)

    it("should remove backticks from wiki_root", function()
        davwiki.setup({
            wiki_root = "~/wiki`whoami`",
        })
        assert.equals("~/wikiwhoami", vim.g.davewiki_root)
    end)

    it("should remove pipe and semicolon from wiki_root", function()
        davwiki.setup({
            wiki_root = "~/wiki|cat /etc/passwd;echo",
        })
        assert.equals("~/wikicat /etc/passwdecho", vim.g.davewiki_root)
    end)
end)
