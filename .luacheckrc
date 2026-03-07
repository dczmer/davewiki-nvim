-- luacheck configuration for nvim-pkms
std = "luajit"
max_line_length = 120

-- Neovim globals
read_globals = {
    "vim",
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
}
