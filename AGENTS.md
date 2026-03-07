# AGENTS.md - Development Guide for nvim-pkms

## Project Overview

This is a Neovim plugin implementing a Personal Knowledge Management System (PKMS), similar to Logseq or Obsidian. It's written in Lua and uses a Nix flake for development environment management.

## Development Environment

This project uses a Nix flake for development. All dependencies are managed via `flake.nix`.

### Enter Development Shell

```bash
nix develop
```

This provides:
- neovim (wrapped with plugin dependencies)
- lua54Packages.luacheck (linting)
- stylua (formatting)
- plenary-nvim (testing framework)
- ripgrep, fd, fzf (telescope dependencies)

## Build/Lint/Test Commands

### Running the Plugin

```bash
nix run
```

### Linting

```bash
# Run luacheck on all Lua files
luacheck lua/
```

### Formatting

```bash
# Format all Lua files with stylua
stylua lua/
```

### Testing

This project uses plenary-nvim for unit testing.

```bash
# Run all tests (from within Neovim)
:PlenaryBustedDirectory tests/ {minimal_init = './init.lua'}

# Run a single test file
:PlenaryBustedFile tests/my_test.lua

# Run a specific test (add to test file)
-- Run specific test: it("should do something", function() ... end)
```

## Code Style Guidelines

### General Principles

- Write idiomatic Lua following Neovim conventions
- Use 4 spaces for indentation (not tabs)
- Maximum line length: 120 characters (soft limit)
- Always use descriptive names for variables and functions

### Naming Conventions

- **Variables/functions**: `snake_case` (e.g., `get_current_buffer`, `parse_tags`)
- **Modules**: `snake_case` (e.g., `davwiki.lua`, `davwiki/utils.lua`)
- **Table keys**: `snake_case`
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `DEFAULT_ROOT`, `MAX_DEPTH`)
- **Filenames**: `snake_case.lua`

### Imports and Requiring Modules

```lua
-- Local variables for module imports (preferred)
local vim = vim
local api = vim.api
local fn = vim.fn

-- Require with local variable
local davwiki = require("davwiki")
local utils = require("davwiki.utils")
```

### Formatting with StyLua

Run `stylua` before committing. Configuration:
- Indent width: 4 spaces
- Column width: 120
- Quote style: Auto-detect (prefer double quotes for strings)

### Types

- Use LuaLS type annotations when beneficial:
```lua
---@param root string
---@return string|nil
local function resolve_root(root)
    -- ...
end
```

- Prefer explicit returns over implicit nil returns

### Error Handling

- Use `vim.notify` or `vim.api.nvim_err_writeln` for user-facing errors
- Return `nil` or error tuple on failure for internal functions
- Use `pcall` or `xpcall` for risky operations:
```lua
local ok, result = pcall(some_function, arg1, arg2)
if not ok then
    vim.notify("Error: " .. result, vim.log.levels.ERROR)
end
```

### Keymapping Guidelines

- Always include `desc` for keymaps (enables which-key integration):
```lua
vim.keymap.set("n", "<leader>tt", function()
    -- implementation
end, { desc = "Toggle NeoTree" })
```

- Use `<Plug>` mappings for script-local mappings when appropriate

### Neovim API Usage

- Use `vim.api.nvim_*` functions over `vim.cmd` when possible
- Use `vim.opt` for settings (not `vim.o`)
- Use `vim.uv` for filesystem operations (LuaJIT co-modules)

### File Structure

```
nvim-pkms/
├── init.lua              -- Neovim bootstrap config
├── lua/
│   └── davwiki/
│       ├── init.lua     -- Main module entry point
│       ├── utils.lua    -- Utility functions
│       └── ...          -- Other modules
├── tests/
│   └── ...              -- Plenary test files
├── flake.nix            -- Nix flake definition
└── README.md
```

### Testing Conventions

- Test files go in `tests/` directory
- Use plenary's busted framework:
```lua
local davwiki = require("davwiki")

describe("davwiki module", function()
    it("should parse tags correctly", function()
        local result = davwiki.parse_tags("#hello #world")
        assert.equals(2, #result)
    end)
end)
```

- Mock vim functions when testing core logic
- Keep tests focused and independent

## Dependencies

Core dependencies (from flake.nix):
- telescope-nvim (search/grep interface)
- nvim-cmp (auto-completion)
- mattn-calendar-vim (calendar features)
- neo-tree-nvim (file explorer, optional)
- which-key-nvim (key binding help)
- plenary-nvim (testing framework)

## Configuration

- Root directory configured via global: `vim.g.davewiki_root`
- Default journal location: `{root}/journals`
- Default tags location: `{root}/tags`
- Default notes location: `{root}/notes`
