local M = {}

local pl = {
    tablex = require "pl.tablex",
    pretty = require "pl.pretty"
}

local fmeta = {
    __index = function (ftable, pattern)
        local keys = pl.tablex.keys(ftable)
        local result = {}
        for _, key in ipairs(keys) do
            if string.match(key, "^" .. pattern) then
                table.insert(result, key)
            end
        end
        if #result == 1 then
            return ftable[result[1]]
        else
            return nil
        end
    end
}

local meta = {}
meta.__index = meta

function M.create()
    local self = { 
        actiontable = {}
    }
    setmetatable(self, meta)
    return self
end

function meta.add_action(self, name, action)
    self.actiontable[name] = action
end

function meta.actions(self)
    return next, self.actiontable
end

function meta.get_action(self, command)
    return self.actiontable[command]
end

function meta.get_collect(self, command)
    if self.actiontable[command] then
        return self.actiontable[command]:get_collect()
    end
end

function meta.get_function(self, command)
    if self.actiontable[command] then
        return self.actiontable[command]:get_function()
    end
end

function meta.get_use_data(self, command)
    if self.actiontable[command] then
        return self.actiontable[command]:get_use_data()
    end
end

function meta.get_save_data(self, command)
    if self.actiontable[command] then
        return self.actiontable[command]:get_save_data()
    end
end

function meta.get_help_message(self, command)
    if self.actiontable[command] then
        return self.actiontable[command]:get_help_message()
    end
end

function meta.get_options(self, command)
    if self.actiontable[command] then
        return self.actiontable[command]:get_options()
    end
end

return M
