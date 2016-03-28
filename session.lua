--{{{ Module loading
local util = require "util"
local rl = require "readline"

local pl = {}
pl.pretty = require "pl.pretty"

local dp = pl.pretty.dump
--}}}

--{{{ General Information
--{{{ Structure of self object
--}}}
--{{{ Structure of action handler
--}}}
--}}}

local M = {}

-- metatable for session objects
local meta = util.new_metatable("sessionlib")
meta.__tostring = function (self) return "session object" end

--{{{ constants, options etc.
M.default_action_handlers = "default_action_handlers"
M.minimal = "minimal"
--}}}
--{{{ Initialization
-- create a new session
function M.create(...)
    -- store options in a table for iteration
    local options = table.pack(...)
    
    -- self object
    local self = {
        line_number = 1,
        open = true, -- flag to quit the session
        name = "lapr",

        functiontable = { 
            ["__empty__"] = { handler = function() end }
        },
        data = { },
        hooks = { },

        last_command = nil,

        unknown_command_handler = nil,

        internal_command_modifier = "^%+",
        options_modifier = "-",

        settings = {
            enable_hooks = true,
            prompt = "%P: %l > ",
            raise_errors = true
        }
    }

    -- check and install options
    for _, option in ipairs(options) do
        if option == M.default_action_handlers then
            self.functiontable.quit = {
                handler = function(self)
                    self.open = false
                end,
                help_message = "quit the session",
                use_data = "quit"
            }
            self.functiontable.help = {
                handler = meta.help,
                help_message = "display a help message",
                use_data = "help"
            }
            self.data["quit"] = self
            self.data["help"] = self
        end
    end

    setmetatable(self, meta)

    return self
end
--}}}
--{{{ Settings
function meta.set_name(self, name)
    self.name = name
end

-- set the prompt of the session
function meta.set_prompt(self)

end

function meta.set_internal_command_modifier(self, modifier)
    -- check validity
    -- the modifier may only be a single character and only some special symbol
    if not string.match(modifier, "^[-+/!#$%^&*'\",.<>:]$") then
        self:raise_or_return_error(string.format("illegal internal command modifier: %s", modifier))
    end
end
--}}}
--{{{ Help functions
-- displays all valid commands
-- or the help message of all specified commands
function meta.help(self, ...)
    if ... then
        -- iterate over all given commands, this works well also for only one command
        for _, command in ipairs({ ... }) do
            -- if we have more than one command, prepend the command name 
            if #{ ... } > 1 then
                print(string.format("%s: ", command))
            end
            -- get the action to read the help message
            local action = self:get_action(command)
            -- the user could specify a wrong command, check this and raise a message
            if action then
                print(action.help_message)
            else
                print(string.format("help: command %s unknown", command))
            end

            print()
        end
    else -- no command specified, print list of commands
        -- build table with all command names and sort them
        local commandnames = {}
        for command in pairs(self.functiontable) do
            if not string.match(command, "__[^_]+__") then
                table.insert(commandnames, command)
            end
        end
        table.sort(commandnames)

        -- print the list
        print("list of commands:\n")
        for _, command in ipairs(commandnames) do
            print(command)
        end
        print()
    end
end
--}}}
--{{{ Managing action handlers (adding, getting etc.)
--{{{ add action
-- add an action handler to the session
-- command is a key (string)
-- the action parameter should be a function (or a callable object)
-- the action function is later called with the session object as first parameter
-- and all arguments of the current commandline stored in a sequence as second parameter
-- the override switch is used to override a existing handler. If override is false, this is not possible
function meta.add_action_handler(self, command, action, help_message, override, save_data, use_data, collect_arguments, options_map)
    local new_handler = { }
    -- arguments supplied sequentially
    if type(command) ~= "table" then
        new_handler = {
            command           = command,
            action            = action,
            help_message      = help_message,
            override          = override,
            save_data         = save_data,
            use_data          = use_data,
            collect_arguments = collect_arguments,
            options_map       = options_map
        }
    -- arguments packed in table
    else
        new_handler = command
    end

    -- check if important keys are valid
    if not new_handler.command then
        return self:raise_or_return_error("handler has no valid command")
    end
    if not new_handler.action then
        self:raise_or_return_error(string.format("handler '%s' has no valid action", new_handler.command))
    end

    -- install handler (if possible)
    if self.functiontable[new_handler.command] and not new_handler.override then
        return nil, string.format("command '%s' already exists. Use the override flag to ignore this and install the new handler", command)
    else
        self.functiontable[new_handler.command] = { 
            handler = new_handler.action, 
            help_message = new_handler.help_message, 
            save_data = new_handler.save_data, 
            use_data = new_handler.use_data,
            collect_arguments = new_handler.collect_arguments
        }
        return true
    end
end
--}}}
--{{{ add a list of action handlers
function meta.add_action_handlers(self, list)
    for _, action in ipairs(list) do
        self:add_action_handler(action)
    end
end
--}}}
--{{{ add action handler from module
-- TODO: finish this.
function meta.add_action_handlers_from_module(self, module, commands, help_messages, options, modulename)
    local modulename = modulename or self:generate_uniq_module_name()
    for i, command in ipairs(commands) do
        -- search for function in module
        local func = module[command]
        if not func then
            self:raise_or_return_error(string.format("function %s in module not found", command))
        end

        local handler = {
            command = command,
            action = func,
            help_message = help_messages[i]
        }
        if options[i] == "save" then
            handler.save_data = modulename
        elseif options[i] == "use" then
            handler.use_data = modulename
        end

        -- install handler
        self:add_action_handler(handler)
    end
end
--}}}
--{{{ get the action handler installed for the command
function meta.get_action(self, command)
    local func = self.functiontable[command]
    if not func then
        return self.unknown_command_handler
    else
        return func
    end
end
--}}}
--{{{ get action checked
function meta.check_command_get_action(self, command)
    local action = self:get_action(command)
    if action then
        return self:check_use_data(action)
    else
        print(string.format("command '%s' not found", command))
        return nil
    end
end
--}}}
--{{{ import from module
-- TODO: unfinished. It should be possible to specify a module (a table) and automitcally import all functions (maybe skip some special ones)
-- think about how to fix the problem with the help message
function meta.import_from_module(self, module)
    for k, v in pairs(module) do
        if type(v) == "function" then

        end
    end
end
--}}}
--}}}
--{{{ Hooks
-- add a hook
function meta.add_hook(self, hook, event, command)
    -- TODO: check validity of event
    if not hook then
        return self:raise_or_return_error("called 'add_hook' without valid function")
    end
    self.hooks[event] = hook
    if command then -- set hook tied to action
        self.hooks[event .. ":" .. command] = hook
    else -- set ordinary hook
        self.hooks[event] = hook
    end
end

-- get a hook
function meta.get_hook(self, event, command)
    if command then -- get hook tied to action
        return self.hooks[event .. ":" .. command]
    else -- get ordinary hook
        return self.hooks[event]
    end
end
--}}}
--{{{ Error handling
function meta.raise_or_return_error(self, msg)
    if self.settings.raise_errors then
        error(msg)
    else
        return nil, msg
    end
end
--}}}
--{{{ Utility functions
--{{{ generate unique module name
function meta.generate_uniq_module_name(self)
    -- TODO increment a counter and return a new modulename
    return "module1"
end
--}}}
--{{{ check use data
function meta.check_use_data(self, action)
    if action.use_data then
        if not self.data[action.use_data] then
            print(string.format("You wanted to use a action on previous data ('%s'), but there is no such data.\nMaybe you need to call some initialization function?", action.use_data))
            return nil
        else
            return action
        end
    else
        return action
    end
end
--}}}
--}}}
--{{{ Prompt functions
-- return to prompt of the session
function meta.prompt(self)
    local prompt = string.gsub(self.settings.prompt, "%%P", self.name)
    prompt = string.gsub(prompt, "%%l", self.line_number)
    return prompt
end
--}}}
--{{{ Action and hook execution, argument handling
--{{{ execute hook
function meta.execute_hook(self, hookstr, suffix)
    if self.settings.enable_hooks then
        local hook = self:get_hook(hookstr, suffix)
        if hook then hook() end
    end
end
--}}}
--{{{ call the action handler
function meta.call_action_handler(self, action, args)
    -- call the handler and optionally save the result
    return action.handler(table.unpack(args))
end
--}}}
--{{{ combine arguments
function meta.combine_arguments(self, action, args)
    -- gather all arguments in one table which can be unpacked later
    local args_combined = {}
    if action.use_data then
        table.insert(args_combined, self.data[action.use_data])
    end
    -- the arguments of the function can be given sequentially or packed in a table
    -- use 'collect_arguments' to change behaviour (collect -> packed)
    if action.collect_arguments then
        table.insert(args_combined, args)
    else
        for i = 1, #args do
            table.insert(args_combined, args[i])
        end
    end

    return args_combined
end
--}}}
--{{{ prepend lookup data
function meta.prepend_lookup_data(self, action, args)
    -- FIXME: currently not used
end
--}}}
--{{{ save data
function meta.save_data(self, action, result)
    if action.save_data then
        self.data[action.save_data] = result
    end
end
--}}}
--}}}
--{{{ Reading and parsing commands
--{{{ Read next command
function meta.next_command(self)
    -- read next command line, save and increment line counter
    local line = rl.readline(self:prompt())
    if not line then
        return nil
    end
    self.line_number = self.line_number + 1
    return line
end
--}}}
--{{{ parse a commandline
function meta.parse_line(self, line)
    -- extract command (first word)
    -- first, check for empty line
    if string.match(line, "^%s*$") then
        return "__empty__", {}
    end
    -- check if the command is an internal command
    -- these commands are specified by using the internal command modifier (can be modified)
    if string.match(line, self.internal_command_modifier) then
        print("internal command")
    end

    local first, last, command = string.find(line, "^(%S+)")
    if not first then -- no valid string
        return nil, string.format("could not parse command line: '%s'", line)
    end

    -- store est of line (arguments)
    local line = string.sub(line, last+1)

    local args = {}
    for word in string.gmatch(line, "%S+") do
        table.insert(args, word)
    end

    return command, args
end
--}}}
--{{{ Apply options to arguments
function meta.apply_options_to_arguments(self, action, args)
    -- TODO: this functions needs more arguments, but i'm currently not sure which exactly
    --
    -- the following mechanisms need to be implemented:
    --      - an option generates arguments and injects them into the args table
    --      - an option causes the specified handler of an action to be called
    --      - an option calls another function before and/or after the actual action handler
    local options_map = self:get_options_map(action)
    local processed_args = {}
    if options_map then
        for _, arg in ipairs(args) do
            if self:is_option(arg) then
                -- process argument
            else -- simply copy argument to final list
                table.insert(processed_args, arg)
            end
        end
    else -- no processing of arguments
        processed_args = args
    end
    local args_combined = self:combine_arguments(action, processed_args)
    if not args_combined then
        return nil
    end
    return action, args_combined
end
--}}}
--{{{ get options map
function meta.get_options_map(self, action)
    return true
    --return nil
end
--}}}
--{{{ is option
function meta.is_option(self, argument)
    -- build matchstring
    local matchstr = "^" .. self.options_modifier .. "%w+$"
    return string.match(argument, matchstr)
end
--}}}
--}}}
--{{{ Main loop functions
function meta.loop(self)
    self:execute_hook("atentry")
    while self.open do
        self:execute_hook("atbegincycle")
        -- read the command line
        local line = self:next_command()
        if not line then
            break
        end

        -- parse the command line
        local command, args = self:parse_line(line)

        -- get the action handler
        local action = self:check_command_get_action(command)
        if action then
            -- execute the 'before' hook, then the action handler, then the 'after' hook (if they exist)
            self:execute_hook("before", command)
            -- process options
            local handler, final_args = self:apply_options_to_arguments(action, args)
            local result = self:call_action_handler(handler, final_args)
            self:save_data(action, result)
            self:execute_hook("after", command)
        end
    end
    self:execute_hook("atexit")
end
--}}}

return M

-- vim: foldmethod=marker
