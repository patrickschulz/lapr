local path = require "pl.path"

local userconfig = {
    datadir = os.getenv("HOME") .. "/.config/lapr/data",
    datafile = "packagelookup.lua",
    configdir = os.getenv("HOME") .. "/.config/lapr",
    configfile = "config.lua"
}

local systemconfig = {
    datadir = "/usr/share/lua/5.3/lapr/data",
    datafile = "packagelookup.lua",
    configdir = "/usr/share/lua/5.3/lapr/config",
    configfile = "config.lua"
}

local M = {}

function M.create_config_directories()
    path.mkdir(userconfig.datadir)
    path.mkdir(userconfig.configdir)
end

function M.get_system_database_name()
    if type(systemconfig.datadir) == "table" then
        if type(systemconfig.datafile) == "table" then

        else

        end
    else
        return systemconfig.datadir .. "/" .. systemconfig.datafile
    end
end

function M.get_user_database_name()
    return userconfig.datadir .. "/" .. userconfig.datafile
end

function M.get_user_config_filename()
    return userconfig.configdir .. "/" .. userconfig.configfile
end

return M
