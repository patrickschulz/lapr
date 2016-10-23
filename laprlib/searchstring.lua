local pl = {}
pl.tablex = require "pl.tablex"
pl.list   = require "pl.List"

local util = require "laprlib.util"

-- do not use a name (mode) for the metatable since this prevents reading the metatable.
-- This is needed for pl.tablex.deepcopy
local meta = util.new_metatable(nil) 

local M = {}

function M.create(str)
    local self = {
        matches = pl.list()
    }

    local oldstart = 1
    repeat
        -- find delimiter
        local start = str:find(":", oldstart)
        -- extract string
        local match = str:sub(oldstart, start and (start - 1))
        -- move previous start to current
        oldstart = (start or str:len()) + 1

        self.matches:append(match)

        if oldstart > str:len() and str:sub(str:len()) == ":" then
            self.matches:append("")
        end
    until oldstart > str:len()

    setmetatable(self, meta)

    return self
end

function meta.strip_prefix(self)
    self.matches:remove(1)
    return self
end

function meta.get_prefix(self)
    return self.matches[1]
end

function meta.copy(sp)
    return pl.tablex.deepcopy(sp)
end

function meta.number(self)
    return self.matches:len()
end

function meta.string_representation(sp)
    return table.concat(sp.matches, ":")
end

function meta.ensure_pattern(self, pattern)
    local pattern = pattern or ""
    if self:number() < 1 then
        print("fixing pattern")
        self.matches:append(pattern)
    end
end

return M
