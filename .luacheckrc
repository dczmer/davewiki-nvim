-- luacheck configuration for nvim-pkms
std = "luajit"
max_line_length = 120
max_code_line_length = 120
max_string_line_length = 120
max_comment_line_length = 120

-- Neovim globals
read_globals = {
    "vim",
}

-- Plugin files can set vim.g globals
files["plugin/**/*.lua"] = {
    ignore = {
        "122", -- Setting read-only field of global (vim.g.davewiki_root)
    },
}

-- Main module can set vim.g globals
files["lua/davewiki.lua"] = {
    ignore = {
        "122", -- Setting read-only field of global (vim.g.davewiki_root)
    },
}

-- Test files use plenary busted globals
files["tests/**/*.lua"] = {
    read_globals = {
        "describe",
        "it",
        "before_each",
        "after_each",
        "assert",
        "pending",
    },
    ignore = {
        "121", -- Setting read-only field of global (mocking vim.api, vim.fn, io.open, etc.)
        "122", -- Setting read-only field of global (same as 121, for nested fields)
        "211", -- Unused variable (test setup/teardown often has unused variables)
        "212", -- Unused argument (mock functions don't use all parameters)
    },
}
