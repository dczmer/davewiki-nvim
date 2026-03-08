-- luacheck configuration for nvim-pkms
std = "luajit"
max_line_length = 120

-- Neovim globals
read_globals = {
    "vim",
}

-- Plugin files can set vim.g globals
files["plugin/**/*.lua"] = {
    ignore = {
        "122",
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
        "121",
        "122",
        "211",
        "212",
    },
}
