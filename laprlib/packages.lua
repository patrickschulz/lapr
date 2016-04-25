local pl = {}
pl.pretty = require "pl.pretty"
pl.tablex = require "pl.tablex"
pl.file = require "pl.file"

local util = require "laprlib.util"

local M = {}
local meta = util.new_metatable("packageslib")
meta.__gc = function(self) self:save() end

function M.load(filename)
    local package_table = pl.file.read(filename)
    if package_table then
        local t = pl.pretty.read(package_table)
        t.filename = filename
        return setmetatable(t, meta)
    else
        return nil, string.format("could not read package database ('%s')", filename)
    end
end

function meta.is_command(self, command)
    return pl.tablex.find(pl.tablex.keys(self.commands), command)
end

function meta.is_environment(self, environment)
    return pl.tablex.find(pl.tablex.keys(self.environments), environment)
end

function meta.is_latex_command(self, command)
    return self.commands[command] == "latex"
end

function meta.is_latex_environment(self, environment)
    return self.environments[environment] == "latex"
end

function meta.ask_package(self, mode, command)
    return util.ask_user(string.format("unknown %s '%s'. which package? > ", mode, command))
end

function meta.get_package(self, mode, cmdenv)
    return self[mode][cmdenv]
end

function meta.insert_command(self, command, package)
    self.commands[command] = package
end

function meta.insert_environment(self, command, package)
    self.environments[command] = package
end

function meta.save(self)
    local rep = pl.pretty.write(self)
    pl.file.write(self.filename, rep)
end

return M
