#! /usr/bin/env lua
local lapp = require "pl.lapp"

local project_lib = require "laprlib.project"
local session_lib = require "laprlib.session"
local util = require "laprlib.util"

local session = session_lib.create(session_lib.default_action_handlers)

local args = lapp[[
lapr - a commandline IDE for LaTeX documents. 
Usage: lapr [options]

Supported options:
    -d,--debug                          turn on debugging features
       --tour                           take an introduction tour
    -n,--noload                         do not load an existing project at startup
    -a,--save                           save project on exit
    -f,--file (default ".project")      filename of project file
    -s,--script (default "")            script to read commands from
    -p,--persist                        start interactive mode after reading a script
    -t,--smart (default "smart")        set level of smartness for package insertion.
                                        possible values:
                                            smart:  insert all conflict-less packages without confirmation
                                            ask:    insert all packages, but ask the user
                                            benno:  don't do anything, since i don't want to be bevormunded!
]]
if args.script == "" then
    args.script = nil
end

session:add_action_handler({
    command = "add",
    action = {
        content = project_lib.add_file,
        aux     = project_lib.add_aux_file,
        package = project_lib.add_package
    },
    help_message = "add is a super command. List of subcommands:\n  content: add a content file\n  aux: add an auxiliary file\n  package: add a package to the preamble",
    use_data = "project_lib"
})
session:add_action_handler({
    command = "edit",
    action = project_lib.edit_file,
    help_message = "edit a file",
    use_data = "project_lib"
})
session:add_action_handler({
    command = "create",
    action = project_lib.create,
    help_message = "create a project",
    save_data = "project_lib"
})
session:add_action_handler({
    command = "create",
    action = project_lib.create,
    help_message = "create a project",
    save_data = "project_lib"
})
session:add_action_handler({
    command = "info",
    action = project_lib.info,
    help_message = "display project information",
    use_data = "project_lib"
})
session:add_action_handler({
    command = "compile",
    action = project_lib.compile,
    help_message = "compile the document",
    use_data = "project_lib"
})
session:add_action_handler({
    command = "view",
    action = project_lib.view,
    help_message = "view the document",
    use_data = "project_lib"
})
session:add_action_handler({
    command = "set",
    action = {
        editor = project_lib.set_editor,
        engine = project_lib.set_latex_engine,
        viewer = project_lib.set_viewer
    },
    help_message = "latex settings",
    use_data = "project_lib"
})
session:add_action_handler({
    command = "reset",
    action = project_lib.reset,
    help_message = "reset settings",
    use_data = "project_lib"
})
session:add_action_handler({
    command = "save",
    action = project_lib.save,
    help_message = "save project",
    use_data = "project_lib"
})
session:add_action_handler({
    command = "load",
    action = project_lib.load,
    help_message = "load project",
    save_data = "project_lib"
})
session:add_hook(function(sessionobj, args) 
    sessionobj:set_prompt(string.format("%s: %%l > ", args[1])) 
end, 
"after", "create")
if args.save then
    session:add_hook(function(sessionobj, args) 
        sessionobj:execute_silent_command("save")
    end, 
    "atexit")
end

if not args.noload then
    if project_lib.check_existing_project() then
        print("autoloading project")
        session:execute_command("load")
    end
end

if args.smart ~= "smart" then
    print("ok, you got me. The --smart option currently does nothing.")
end

if args.script then
    session:load_script(args.script)
end

if not args.script or args.persist then
    session:loop()
end

-- vim: nowrap ft=lua
