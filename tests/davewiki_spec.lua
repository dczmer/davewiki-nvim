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
end)
