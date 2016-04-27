local M = {}

local debug = false

function M.enable(bool)
    debug = bool
end

function M.message(msg)
    if debug then
        print(msg)
    end
end

return M
