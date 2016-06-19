local M = {}

local pl = {}
pl.file = require "pl.file"

function M.edit(content)
    local content = content or ""
    pl.file.write("__tmp", content)
    os.execute("vim __tmp")
    local new_content = pl.file.read("__tmp")
    os.remove("__tmp")
    return new_content
end

return M
