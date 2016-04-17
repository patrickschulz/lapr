local project_lib = require "project"
local session_lib = require "session"

local session = session_lib.create(session_lib.default_action_handlers)

if arg[1] == "-d" or arg[1] == "--debug" then
    print("starting debug mode")
    session:set_debug_mode("all")
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

session:loop()

-- vim: nowrap
