local path = require "pl.path"

local userconfig = {
    datadir = os.getenv("HOME") .. "/.config/lapr/data",
    datafile = "packagelookup.lua",
    configdir = os.getenv("HOME") .. "/.config/lapr",
    configfile = "config.lua"
}

local systemconfig = {
    --datadir = "/usr/share/lua/5.3/lapr/data",
    datadir = "/home/pschulz/Workspace/lua/lapr/data",
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
    return systemconfig.datadir .. "/" .. systemconfig.datafile
end

function M.get_user_database_name()
    return userconfig.datadir .. "/" .. userconfig.datafile
end

return M
