local M = {}

local util = require "laprlib.util"

local meta = util.new_metatable("actionlib")

function M.create(func, help, options)
    local options = options or {}
    local self = {
        func = func,
        help = help,
        use = options.use,
        save = options.save,
        collect = options.collect,
        options = options.options
    }
    setmetatable(self, meta)
    return self
end

function meta.get_function(self)
    return self.func
end

function meta.get_help_message(self)
    return self.help
end

function meta.get_use_data(self)
    return self.use
end

function meta.get_save_data(self)
    return self.save
end

function meta.get_collect(self)
    return self.collect
end

function meta.get_options(self)
    return self.options
end

return M
