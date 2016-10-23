#! /usr/bin/env lua
local lapp = require "pl.lapp"

local projectlib = require "laprlib.project"
local sessionlib = require "laprlib.session"
local util = require "laprlib.util"
local config = require "laprlib.config"

config.create_config_directories()

local session = sessionlib.create(sessionlib.default_action_handlers)

local args = lapp[[
lapr - a commandline IDE for LaTeX documents. 
Usage: lapr [options]

Supported options:
    -d,--debug                          turn on debugging features
    -n,--noload                         do not load an existing project at startup
    -a,--save                           save project on exit
    -s,--script (default "")            script to read commands from
    -p,--persist                        start interactive mode after reading a script
    -v,--version                        display version information and exit
]]
if args.version then
    print([[lapr - a commandline IDE for LaTeX documents
Development Version 0.1]])
    os.exit(0)
end
if args.script == "" then
    args.script = nil
end
if args.save then
    session:add_hook(function(sessionobj, args) 
        sessionobj:execute_silent_command("save")
    end, 
    "atexit")
end

session:add_action_handler{
    command = "create",
    action = projectlib.create,
    help_message = "Create a new project.\nArguments: document name, LaTeX class",
    save_data = "projectlib"
}
session:add_action_handler{
    command = "structure",
    action = {
        define = projectlib.define_structure,
        list = projectlib.list_structure,
        edit = projectlib.edit_structure_element
    },
    help_message = 
[[Structure manipulation
define: define the structure interactively
list:   list the current document structure
edit:   edit a structure element. The element is found by supplying a pattern]],
    use_data = "projectlib"
}

if not args.noload then
    if projectlib.check_existing_project() then
        print("autoloading project")
        session:execute_command("load")
    end
end

if args.script then
    session:load_script(args.script)
end

if not args.script or args.persist then
    session:loop()
end

-- vim: nowrap ft=lua
