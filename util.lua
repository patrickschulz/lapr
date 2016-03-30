local M = {}

local pl = {}
pl.file = require "pl.file"
pl.path = require "pl.path"

--{{{ new metatable
function M.new_metatable(mode)
    local meta = {}
    meta.__index = meta
    meta.__metatable = mode
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

return M

-- vim: foldmethod=marker
