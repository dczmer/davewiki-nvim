local davwiki = require("davewiki")
local cmp = require("cmp")

describe("davwiki", function()
    it("should have a setup function", function()
        assert.is_function(davwiki.setup)
    end)

    it("should accept configuration options", function()
        local config = {
            enabled = true,
            root = "/test/path",
        }
        local result = davwiki.setup(config)
        assert.is_table(result)
        assert.is_true(result.config.enabled)
        assert.equals("/test/path", result.config.root)
    end)

    it("should handle empty config", function()
        local result = davwiki.setup()
        assert.is_table(result)
    end)
end)
