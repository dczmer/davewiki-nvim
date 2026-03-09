# Overview

A Neovim plugin for Personal Knowledge Management, inspired by Logseq and Obsidian. Built with telescope.nvim for search and nvim-cmp for tag completion.

## Features

- **Daily Journals**: Quick navigation to today/yesterday/tomorrow, browse all journals, or jump to any date
- **Tag System**: Tags (`#tagname`) are auto-converted to markdown links pointing to `source/#tagname.md`
- **Fast Search**: Ripgrep-powered telescope pickers for headings, tags, and backlinks
- **Auto-completion**: nvim-cmp source for tag completion with occurrence counts
- **Backlinks**: Find all files linking to the current document

## Directory Structure

```
~/vimwiki/              # Configurable wiki root
├── journal/            # Daily notes (YYYY-MM-DD.md)
├── source/             # Tag files (#tagname.md)
└── notes/              # Hierarchical notes
```

## Dependencies

- `telescope.nvim` - Search interface
- `nvim-cmp` - Auto-completion (optional)
- `ripgrep` - Fast text search
- `which-key.nvim` - Keybinding help (optional)

# Configuration

```lua
local davewiki = require("davewiki").setup({
    telescope = true,  -- Enable telescope integration (default: true)
    cmp = true,        -- Enable nvim-cmp integration (default: true)
    journal = true,    -- Enable journal features (default: true)
    wiki_root = "~/vimwiki"
})

-- nvim-cmp setup with wiki_tags source
local cmp = require("cmp")
davewiki.cmp.setup()
cmp.setup({
    -- ...
    sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "wiki_tags" },  -- Provides tag completion
        { name = "buffer" },
        { name = "path" },
    }),
})

-- Key mappings (<leader>w = wiki)
vim.keymap.set("n", "<leader>wj", davewiki.journal.today, { desc = "Today's journal" })
vim.keymap.set("n", "<leader>wy", davewiki.journal.yesterday, { desc = "Yesterday's journal" })
vim.keymap.set("n", "<leader>wT", davewiki.journal.tomorrow, { desc = "Tomorrow's journal" })
vim.keymap.set("n", "<leader>wJ", davewiki.journal.browse, { desc = "Browse journals" })
vim.keymap.set("n", "<leader>wc", davewiki.journal.calendar, { desc = "Go to date" })
vim.keymap.set("n", "<leader>wh", davewiki.telescope.search_headings, { desc = "Search headings" })
vim.keymap.set("n", "<leader>w#", davewiki.telescope.search_tags, { desc = "Browse tags" })
vim.keymap.set("n", "<leader>wi", davewiki.telescope.insert_tag, { desc = "Insert tag" })
vim.keymap.set("n", "<leader>wb", davewiki.telescope.backlinks, { desc = "Backlinks" })
```
