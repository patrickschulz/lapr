--[[
This file belongs to the lapr project.

General utility for all modules.
--]]
local M = {}

local pl = {}
pl.file = require "pl.file"
pl.path = require "pl.path"
pl.pretty = require "pl.pretty"

--{{{ new metatable
-- creates a table and sets it as its own metatable
-- also, prevents from overwriting by setting the metatable field
-- provides a 'tostring' method for easiert debugging and printing
function M.new_metatable(mode)
    local meta = {}
    meta.__index = meta
    meta.__metatable = mode
    meta.__tostring = function(self) return mode .. "_object" end
    return meta
end
--}}}
--{{{ debug print
function M.debug_print(object, indent)
    local indent = indent or 0
    if type(object) == "table" then
        if #object == 0 then
            io.write(string.format("%s{ }\n", string.rep(" ", 4 * indent)))
        else
            io.write(string.format("%s{\n", string.rep(" ", 4 * indent)))
            for k, v in pairs(object) do
                io.write(string.format("%s[%s] = ", string.rep(" ", 4 * (indent + 1)), tostring(k)))
                M.debug_print(v, -1)
            end
            print(string.format("%s}", string.rep(" ", 4 * indent)))
        end
    elseif type(object) == "string" then
        io.write(string.format("%s\"%s\",\n", string.rep(" ", 4 * (indent + 1)), tostring(object)))
    else
        io.write(string.format("%s%s,\n", string.rep(" ", 4 * (indent + 1)), tostring(object)))
    end
end
--}}}
--{{{ debug table
function M.debug_table(t)
    pl.pretty.dump(t)
end
--}}}
--{{{ write file with extension
function M.write_file_with_extension(filename, extension, content, subdir)
    -- check the extension for a . (dot)
    -- with this, the user of this function can use both (e.g.) ".tex" and "tex"
    if string.sub(extension, 1, 1) == "." then
        extension = string.sub(extension, 2)
    end
    if subdir then
        filename_ext = subdir .. "/" .. filename .. "." .. extension
    else
        filename_ext = filename .. "." .. extension
    end
    pl.file.write(filename_ext, content)
end
--}}}
--{{{ write tex file
function M.write_tex_file(filename, content, subdir)
    M.write_file_with_extension(filename, "tex", content, subdir)
end
--}}}
--{{{ write sty file
function M.write_sty_file(filename, content, subdir)
    M.write_file_with_extension(filename, "sty", content, subdir)
end
--}}}
--{{{ is hidden
function M.is_hidden(filename)
    return pl.path.basename(filename):sub(1, 1) == "."
end
--}}}
--{{{ ask user
function M.ask_user(prompt)
    io.stdout:write(prompt)
    local line = io.stdin:read()
    return line
end
--}}}
--{{{ formatted printing -- printf
function M.printf(format, ...)
    print(string.format(format, ...))
end
--}}}
--{{{ protected printing -- printq
function M.printq(str)
    print(string.format("%q", str))
end
--}}}
--{{{ bind
--TODO: make this handle all number of arguments by using load()
function M.bind(func, arg, value)
    if arg == 1 then
        return function(...) func(value, ...) end
    elseif arg == 2 then
        return function(a1, ...) func(a1, value, ...) end
    elseif arg == 3 then
        return function(a1, a2, ...) func(a1, a2, value, ...) end
    elseif arg == 4 then
        return function(a1, a2, a3, ...) func(a1, a2, a3, value, ...) end
    elseif arg == 5 then
        return function(a1, a2, a3, a4, ...) func(a1, a2, a3, a4, value, ...) end
    elseif arg == 6 then
        return function(a1, a2, a3, a4, a5, ...) func(a1, a2, a3, a4, a5, value, ...) end
    elseif arg == 7 then
        return function(a1, a2, a3, a4, a5, a6, ...) func(a1, a2, a3, a4, a5, a6, value, ...) end
    elseif arg == 8 then
        return function(a1, a2, a3, a4, a5, a6, a7, ...) func(a1, a2, a3, a4, a5, a6, a7, value, ...) end
    elseif arg == 9 then
        return function(a1, a2, a3, a4, a5, a6, a7, a8, ...) func(a1, a2, a3, a4, a5, a6, a7, a8, value, ...) end
    else
    end
end
--}}}
--{{{ counter
function M.counter(start, increment)
    local start = start or 1
    local increment = increment or 1
    return function()
        start = start + increment
        return start
    end
end
--}}}

return M

-- vim: foldmethod=marker
