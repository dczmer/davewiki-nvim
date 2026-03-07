# AGENTS.md - Development Guide for nvim-pkms

## Project Overview

Neovim plugin implementing a Personal Knowledge Management System (PKMS), similar to Logseq/Obsidian. Written in Lua, built and managed entirely via a Nix flake. The core module is `davwiki` (source in `lua/davwiki/`).

Key concepts: journal files (`{root}/journals`), tag files (`{root}/tags`, prefixed with `#`), and hierarchical notes (`{root}/notes`). Content is organized in indented "blocks" that can be extracted by tag for cross-document aggregation.

## Development Environment

All dependencies are managed via `flake.nix` -- there is no lazy.nvim, packer, or other Lua plugin manager.

```bash
nix develop   # Enter dev shell (provides luacheck, stylua, ripgrep, fd, fzf)
nix run       # Launch wrapped Neovim with all plugins loaded
```

The bootstrap config `init.lua` is loaded automatically by the Nix-wrapped Neovim. Leader key is `,`, local leader is `\`.

## Build/Lint/Test Commands

Run tests using `nix run`. The wrapped-version of neovim provided by flake.nix is called `nvim-pkms`.

Example of running a test:
```bash
nix run . -- --headless -u scripts/init.lua -c 'PlenaryBustedFile tests/davewiki_spec.lua' -c 'qa!'
```

```bash
# Lint all Lua source files
luacheck lua/

# Format all Lua source files (run before every commit)
stylua lua/
```

### Testing (plenary-nvim busted framework)

```vim
" Run all tests (from within Neovim started via `nix run`)
:PlenaryBustedDirectory tests/ {minimal_init = './init.lua'}

" Run a single test file
:PlenaryBustedFile tests/some_test.lua
```

Test files go in the `tests/` directory. Use plenary's busted-style DSL:

```lua
describe("davwiki.tags", function()
    it("should parse tags from text", function()
        local tags = require("davwiki.tags")
        local result = tags.parse("#hello #world")
        assert.equals(2, #result)
    end)
end)
```

Keep tests focused and independent. Mock `vim.*` functions when testing pure logic.

## File Structure

```
nvim-pkms/
├── init.lua           -- Neovim bootstrap config (cmp, telescope, neo-tree, which-key)
├── lua/davwiki/       -- Core plugin source (module: require("davwiki"))
│   └── *.lua          -- Submodules (utils, tags, journals, etc.)
├── plugin/            -- Neovim auto-loaded scripts (commands, autocommands)
├── doc/               -- Neovim help documentation
├── tests/             -- Plenary busted test files
├── flake.nix          -- Nix flake (build, devShell, dependencies)
└── flake.lock         -- Pinned Nix dependency versions
```

## Code Style Guidelines

### Naming Conventions

| Entity | Convention | Examples |
|---|---|---|
| Variables, functions | `snake_case` | `get_current_buffer`, `parse_tags` |
| Modules, filenames | `snake_case` | `davwiki/utils.lua` |
| Table keys | `snake_case` | `{ root_dir = "..." }` |
| Constants | `SCREAMING_SNAKE_CASE` | `DEFAULT_ROOT`, `MAX_DEPTH` |

### Formatting

- 4 spaces for indentation (no tabs)
- 120 character column width (soft limit)
- Run `stylua` before committing (indent_width=4, column_width=120)
- Prefer double quotes for strings

These settings are enforced by `.stylua.toml` and `.luacheckrc` in the repo root.

### Imports

```lua
-- Alias vim APIs at the top of each file
local vim = vim
local api = vim.api
local fn = vim.fn

-- Require modules into local variables
local davwiki = require("davwiki")
local utils = require("davwiki.utils")
```

### Type Annotations

Use LuaLS annotations for function signatures and complex types:

```lua
---@param root string The PKMS root directory path
---@return string|nil path Resolved path, or nil on failure
local function resolve_root(root)
    ...
end
```

Prefer explicit `return nil` over implicit nil returns.

### Error Handling

- **User-facing errors**: `vim.notify("message", vim.log.levels.ERROR)`
- **Internal functions**: Return `nil` or `nil, error_string` on failure
- **Risky operations**: Wrap with `pcall`/`xpcall`:
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
vim.keymap.set("n", "<leader>tt", function() ... end, { desc = "Toggle NeoTree" })
```
- Use `vim.opt` for settings (not `vim.o`)
- Use `vim.uv` (libuv bindings) for filesystem operations

## Dependencies (from flake.nix)

### Vim Plugins (loaded as `start` packages)

| Plugin | Purpose |
|---|---|
| `plenary-nvim` | Utility library and test framework |
| `telescope-nvim` + `telescope-fzf-native-nvim` | Fuzzy search interface |
| `nvim-cmp` + `cmp-buffer` + `cmp-path` + `cmp-nvim-lsp` + `cmp-nvim-lsp-signature-help` | Auto-completion |
| `mattn-calendar-vim` | Calendar/date features for journals |
| `neo-tree-nvim` | File explorer sidebar |
| `which-key-nvim` | Keybinding discovery |
| `vim-markdown` | Markdown syntax and features |
| `lz-n` | Lazy loading framework (available but not yet used) |

### CLI Tools (in dev shell PATH)

`ripgrep`, `fd`, `fzf` (telescope backends), `luacheck` (linting), `stylua` (formatting)

## Configuration

- Root directory: `vim.g.davewiki_root`
- Journals: `{root}/journals`
- Tags: `{root}/tags`
- Notes: `{root}/notes`
