--[[
This file belongs to the lapr project.

This module manages the loading, administration and saving of the package database.
--]]
local pl = {}
pl.pretty = require "pl.pretty"
pl.tablex = require "pl.tablex"
pl.file = require "pl.file"

local dp = pl.pretty.dump

local util = require "laprlib.util"
local config = require "laprlib.config"
local debug = require "laprlib.debug"

local M = {}
local meta = util.new_metatable("packageslib")
meta.__gc = function(self) self:save() end

local function internal_load(filename, mode)
    local package_table = pl.file.read(filename)
    local database = { commands = {}, environments = {} }
    if package_table then
        local t = pl.pretty.read(package_table)
        if t then
            database = t
        else
            debug.message(string.format("error while reading %s package database ('%s')", mode, filename))
        end
    else
        debug.message(string.format("could not read %s package database ('%s')", mode, filename))
    end
    return database
end

local function get_new_packages_representation(database)
    local system_database = internal_load(config.get_system_database_name(), "system") 
    local new_database = { commands = {}, environments = {} }
    for command, package in pairs(database.commands) do
        if not system_database.commands[command] then
            new_database.commands[command] = package
        end
    end
    for env, package in pairs(database.environments) do
        if not system_database.environments[env] then
            new_database.environments[env] = package
        end
    end
    if pl.tablex.size(new_database.commands) == 0 and pl.tablex.size(new_database.environments) == 0 then
        return nil
    else
        return pl.pretty.write(new_database)
    end
end

function M.load()
    -- system
    local filename = config.get_system_database_name()
    local system_database = { commands = {}, environments = {} }
    if type(filename) == "table" then
        for _, fname in ipairs(filename) do
            local temp = internal_load(fname, "system")
            local commands = pl.tablex.merge(system_database.commands, temp.commands, true)
            local environments = pl.tablex.merge(system_database.environments, temp.environments, true)
            system_database.commands = commands
            system_database.environments = environments
        end
    else
        system_database = internal_load(filename, "system")
    end
    -- user
    filename = config.get_user_database_name()
    local user_database = internal_load(filename, "user")

    -- merge both tables
    local commands = pl.tablex.merge(system_database.commands, user_database.commands, true)
    local environments = pl.tablex.merge(system_database.environments, user_database.environments, true)
    return setmetatable({ commands = commands, environments = environments }, meta)
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
    local rep = get_new_packages_representation(self)
    if rep then
        local filename = config.get_user_database_name()
        if not pl.file.write(filename, rep) then
            debug.message(string.format("could not write user database to file '%s'", filename))
        end
    end
end

return M
