local davwiki = {}

function davwiki.setup(opts)
    opts = opts or {}
    vim.g.davewiki_root = opts.root or vim.g.davewiki_root
    return davwiki
end

return davwiki
