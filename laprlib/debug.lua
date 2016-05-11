--[[
This file belongs to the lapr project.

It provides a debug interface for all other modules.
--]]

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
