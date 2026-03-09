# AGENTS.md - Development Guide for davewiki-nvim

## Project Overview

Neovim plugin implementing a Personal Knowledge Management System (PKMS), similar to Logseq/Obsidian. Written in Lua, built and managed entirely via a Nix flake.

Key concepts:
- **Journals**: Daily notes in `{root}/journal/` (format: `YYYY-MM-DD.md`)
- **Tags**: Short identifiers (`#tagname`) stored as `source/#tagname.md`
- **Notes**: Hierarchical notes in `{root}/notes/`

Tags are auto-converted to markdown links. Content is organized in indented "blocks" that can be extracted by tag for cross-document aggregation.

## Development Environment

All dependencies are managed via `flake.nix` -- there is no lazy.nvim, packer, or other Lua plugin manager.

```bash
nix develop   # Enter dev shell (provides luacheck, stylua, ripgrep, fd, fzf)
nix run       # Launch wrapped Neovim with all plugins loaded
```

**Important**: If a source file cannot be found when running `nix run`, ensure the file has been added to the git index. Nix flakes only see git-tracked files.

The bootstrap config `init.lua` is loaded automatically by the Nix-wrapped Neovim. Leader key is `,`, local leader is `\`.

## Build/Lint/Test Commands

### Run All Tests (required before commit)

```bash
make           # Runs lint + all tests (run before every commit)
make test      # Run all tests only
make lint      # Run luacheck only
make format    # Run stylua formatter
```

### Run a Single Test

```bash
nvim-pkms --headless -u scripts/init.lua -c 'PlenaryBustedFile tests/davewiki-core_spec.lua' -c 'qa!'
```

Replace `davewiki-core_spec.lua` with the specific test file you want to run.

### Lint and Format

```bash
luacheck -- lua/ plugin/ tests/
stylua -- lua/ plugin/ tests/
```

## File Structure

```
davewiki-nvim/
├── init.lua              -- Neovim bootstrap config (cmp, telescope, which-key)
├── lua/                   -- Core plugin source
│   ├── davewiki.lua       -- Main module with setup() (require("davewiki"))
│   ├── davewiki-core.lua  -- Core utilities: tags, backlinks, ripgrep
│   ├── davewiki-journal.lua -- Daily journal navigation
│   ├── davewiki-telescope.lua -- Telescope pickers
│   └── davewiki-cmp.lua   -- nvim-cmp source for tag completion
├── plugin/                -- Neovim auto-loaded scripts (currently empty)
├── scripts/
│   ├── init.lua           -- Test bootstrap script
│   └── manual-init.lua    -- Manual testing config
├── tests/                 -- Plenary busted test files
│   ├── davewiki_spec.lua
│   ├── davewiki-core_spec.lua
│   ├── davewiki-journal_spec.lua
│   ├── davewiki-telescope_spec.lua
│   └── davewiki-cmp_spec.lua
├── flake.nix              -- Nix flake (build, devShell, dependencies)
└── flake.lock             -- Pinned Nix dependency versions
```

## Code Style Guidelines

### Naming Conventions

| Entity | Convention | Examples |
|---|---|---|
| Variables, functions | `snake_case` | `get_current_buffer`, `parse_tags` |
| Modules, filenames | `snake_case` | `davewiki-core.lua` |
| Table keys | `snake_case` | `{ root_dir = "..." }` |
| Constants | `SCREAMING_SNAKE_CASE` | `DEFAULT_ROOT`, `MAX_DEPTH` |
| Module table | `M` | `local M = {}` then `M.function_name = function()` |

### Formatting

- 4 spaces for indentation (no tabs)
- 120 character column width
- Double quotes preferred for strings (`quote_style = "AutoPreferDouble"`)
- Always use parentheses for function calls (`call_parentheses = "Always"`)

Settings enforced by `.stylua.toml` and `.luacheckrc`.

### Imports

```lua
-- Standard library aliases at the top
local vim = vim
local api = vim.api
local fn = vim.fn

-- Telescope modules (when needed)
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

-- Internal modules
local wiki = require("davewiki-core")
```

### Module Pattern

```lua
local M = {}

M.function_name = function(args)
    -- implementation
end

return M
```

### Type Annotations

Use LuaLS annotations for function signatures:

```lua
---@param root string The PKMS root directory path
---@return string|nil path Resolved path, or nil on failure
local function resolve_root(root)
    ...
end

---@class davewiki.SetupOpts
---@field wiki_root string Root directory for wiki files
---@field telescope boolean Enable telescope integration (default: true)
```

Prefer explicit `return nil` over implicit nil returns.

### Error Handling

- **User-facing errors**: `vim.notify("message", vim.log.levels.ERROR)`
- **Internal functions**: Return `nil` or `nil, error_string` on failure
- **Risky operations**: Wrap with `pcall`/`xpcall`

```lua
local ok, result = pcall(risky_function, arg)
if not ok then
    vim.notify("Error: " .. result, vim.log.levels.ERROR)
end
```

### Neovim API Preferences

- Prefer `vim.api.nvim_*` over `vim.cmd` for buffer/window/autocommand operations
- Use `vim.keymap.set` for keymaps; always include `desc` for which-key:

```lua
vim.keymap.set("n", "<leader>wj", davewiki.journal.today, { desc = "Today's journal" })
```

- Use `vim.opt` for settings (not `vim.o`)
- Use `vim.fn.expand()` for path expansion
- Use `vim.fn.fnameescape()` when passing paths to `:edit` or similar commands

## Testing (plenary-nvim busted framework)

Test files go in `tests/` directory. Name test files `{module_name}_spec.lua`.

```lua
describe("davewiki-core", function()
    describe("find_tags", function()
        it("should return empty table when no tags found", function()
            -- Mock vim.g and wiki.ripgrep
            vim.g.davewiki_root = "/test/wiki"
            local wiki = require("davewiki-core")
            -- ... test implementation
            assert.equals(0, #result)
        end)
    end)
end)
```

**Testing tips**:
- Mock `vim.*` functions when testing pure logic
- Use `before_each`/`after_each` for setup/teardown
- Keep tests focused and independent

## Dependencies (from flake.nix)

### Vim Plugins (loaded as `start` packages)

| Plugin | Purpose |
|---|---|
| `plenary-nvim` | Utility library and test framework |
| `telescope-nvim` + `telescope-fzf-native-nvim` | Fuzzy search interface |
| `nvim-cmp` + `cmp-buffer` + `cmp-path` + `cmp-nvim-lsp` | Auto-completion |
| `which-key-nvim` | Keybinding discovery |
| `vim-markdown` | Markdown syntax and features |

### CLI Tools (in dev shell PATH)

`ripgrep`, `fd`, `fzf` (telescope backends), `luacheck` (linting), `stylua` (formatting)

## Configuration

- Root directory: `vim.g.davewiki_root` (defaults to `~/vimwiki`)
- Journals: `{root}/journal/`
- Tags: `{root}/source/#tagname.md`
- Notes: `{root}/notes/`
