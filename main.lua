local project_lib = require "project"
local session_lib = require "session"

local session = session_lib.create(session_lib.default_action_handlers)

--if arg[1] == "-d" or arg[1] == "--debug" then
    print("starting debug mode")
    session:set_debug_mode("all")
--end

session:add_action_handlers({
    { command = "create", action = project_lib.create, help_message = "create a project", save_data = "projectlib" },
    { command = "load", action = project_lib.load, help_message = "load a project", save_data = "projectlib" },
    { command = "save", action = project_lib.save, help_message = "save project configuration", use_data = "projectlib" },
    { command = "info", action = project_lib.info, help_message = "display project information", use_data = "projectlib" },
    { command = "view", action = project_lib.view, help_message = "view the document", use_data = "projectlib" },
    { command = "aux", action = project_lib.add_aux_file, help_message = "add a auxiliary file", use_data = "projectlib" },
    { command = "edit_preamble", action = project_lib.edit_preamble, help_message = "edit the preamble of the document", use_data = "projectlib" },
    { command = "add", action = project_lib.add_file, help_message = "add a file to the project", use_data = "projectlib", collect_arguments=true },
    { command = "edit", action = project_lib.edit_file, help_message = "edit a file", use_data = "projectlib" },
    { command = "compile", action = project_lib.compile, help_message = "compile the document", use_data = "projectlib" },
    { command = "cleanup", action = project_lib.clean_up, help_message = "do a clean up: (re)move all files that don't belong to the project. Use 'add_aux_file' to protect files.", use_data = "projectlib" },
})

session:add_options_map_to_handler("help", { foo = "bar" })

session:loop()

-- vim: nowrap
