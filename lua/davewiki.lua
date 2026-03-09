local davwiki = {}

---@class davewiki.SetupOpts
---@field wiki_root string Root directory for wiki files
---@field telescope boolean Enable telescope integration (default: true)
---@field cmp boolean Enable nvim-cmp integration (default: true)
---@field journal boolean Enable journal features (default: true)

---@param opts? davewiki.SetupOpts Configuration options
function davwiki.setup(opts)
    if vim.fn.has("nvim-0.10") == 0 then
        vim.notify("davewiki requires Neovim 0.10+", vim.log.levels.ERROR)
        return
    end

    opts = opts or {}
    vim.g.davewiki_root = opts.wiki_root or vim.g.davewiki_root

    if opts.telescope == nil or opts.telescope then
        davwiki.telescope = require("davewiki-telescope")
    end

    if opts.cmp == nil or opts.cmp then
        davwiki.cmp = require("davewiki-cmp")
    end

    if opts.journal == nil or opts.journal then
        davwiki.journal = require("davewiki-journal")
    end

    return davwiki
end

return davwiki
