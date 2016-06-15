--[[
This file belongs to the lapr project.

This module provides a generic interface for settings of modules.
--]]

local M = {}

local meta = util.new_metatable("settings")

function M.create(lib, list)
    local self = { 
        lib = lib,
        values = list
    }

    setmetatable(self, meta)

    return self
end

function meta.get(self, value)
    return self.values[value]
end

function meta.set(self, value, set)
    self.values[value] = set
end

function meta.is_set(self, value)
    return self.values[value] ~= nil
end

return M
