std = {
    read_globals = {
        -- standard global symbols
        "_ENV",
        "arg",
        "os",
        "io",
        "table",
        "string",
        "math",
        "debug",
        "assert",
        "error",
        "ipairs",
        "pairs",
        "print",
        "pcall",
        "type",
        "tostring",
        "tonumber",
        "setmetatable",
        "rawset",
        -- opc global symbols
        "_load_module",
        "_get_opc_home",
        "_get_reader",
        "_generic_load",
        "point",
        "pcell",
        "object",
        "shape",
        "graphics",
        "geometry",
        "generics",
        "abstract",
        "stringfile",
        "config",
        "reduce",
        "util",
        "stack",
        "aux",
        "bind",
        "enable",
        "funcobject",
        -- layermap globals
        "map",
        "array",
        "refer",
    },
    globals = {
        "parameters",
        "layout",
    }
}

exclude_files = {
    "testsuite/module/modules/syntaxerror.lua",
    "doc",
}

codes = true
quiet = 1
max_line_length = false

-- vim: ft=lua
