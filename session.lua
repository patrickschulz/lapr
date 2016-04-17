--{{{ Module loading
local util = require "util"
local rl = require "readline"

local pl = {}
pl.pretty = require "pl.pretty"
pl.utils = require "pl.utils"
pl.tablex = require "pl.tablex"

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
            functions = { ["__empty__"] = function() end },
            help_messages = {},
            use_data = {},
            save_data = {},
            collect_arguments = {},
            options_map = {}
        },
        data = { },
        hooks = { },

        last_command = nil,

        internal_command_modifier = "+",
        options_modifier = "-",

        settings = {
            enable_hooks = true,
            prompt = "%P: %l > ",
            raise_errors = true,
            debug_mode = "none"
        }
    }

    -- check and install options
    for _, option in ipairs(options) do
        if option == M.default_action_handlers then
            self.functiontable.functions["help"] = meta.help
            self.functiontable.help_messages["help"] = "display a help message"
            self.functiontable.use_data["help"] = "help"
            self.data["help"] = self

            self.functiontable.functions["quit"] = function(self) self.open = false end
            self.functiontable.help_messages["quit"] = "quit the session"
            self.functiontable.use_data["quit"] = "quit"
            self.data["quit"] = self

        end
    end

    self.functiontable.functions["+set"] = meta.set
    self.functiontable.use_data["+set"] = "+set"
    self.data["+set"] = self

    setmetatable(self, meta)

    return self
end
--}}}
--{{{ Settings
--{{{ generic set function
function meta.set(self, mode, ...)
    local args = { ... }
    if mode == "line" then
        self.line_number = 1
    end
end
--}}}
--{{{ set name
function meta.set_name(self, name)
    self.name = name
end
--}}}
--{{{ set prompt
function meta.set_prompt(self)

end
--}}}
--{{{ set internal command modifier
function meta.set_internal_command_modifier(self, modifier)
    -- check validity
    -- the modifier may only be a single character and only some special symbol
    if not string.match(modifier, "^[-+/!#$%^&*'\",.<>:]$") then
        return self:raise_or_return_error(string.format("illegal internal command modifier: %s", modifier))
    end
    self.internal_command_modifier = modifier
end
--}}}
--}}}
--{{{ Help functions
-- displays all valid commands
-- or the help message of all specified commands
function meta.help(self, ...)
    if ... == "-internal" then
        -- build table with all command names and sort them
        local commandnames = {}
        for command in pairs(self.functiontable.functions) do
            if self:is_internal_command(command) then
                table.insert(commandnames, command)
            end
        end
        table.sort(commandnames)

        -- print the list
        print("list of internal commands:\n")
        for _, command in ipairs(commandnames) do
            print(command)
        end
        print()
        return
    end
    if ... then
        -- iterate over all given commands, this works well also for only one command
        for _, command in ipairs({ ... }) do
            -- if we have more than one command, prepend the command name 
            if #{ ... } > 1 then
                print(string.format("%s: ", command))
            end
            -- get the action to read the help message
            local help_message = self:get_help_message(command)
            print(string.format("%s\n", help_message))
        end
    else -- no command specified, print list of commands
        -- build table with all command names and sort them
        local commandnames = {}
        for command in pairs(self.functiontable.functions) do
            if not (self:is_internal_command(command) or self:is_hidden_command(command)) then
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
--{{{ Getter for functiontable
--{{{ get function
function meta.get_function(self, command, args)
    local func = self.functiontable.functions[command]
    if not func then
        return nil, string.format("command '%s' unknown", command)
    else
        if pl.utils.is_type(func, "function") then
            return func
        elseif pl.utils.is_type(func, "table") then -- func is a table, lookup the actual function based on the arguments (subcommands)
            local subcommand = args and args[1]
            if not subcommand then
                local keys = pl.tablex.keys(func)
                table.sort(keys)
                local list_of_subcommands = table.concat(keys, ", ")
                return nil, string.format("command '%s' must be followed by a subcommand: { %s }", command, list_of_subcommands)
            else
                if not pl.tablex.find(pl.tablex.keys(func), subcommand) then
                    return nil, string.format("unknown subcommand (%s) for command '%s'", subcommand, command)
                else
                    return func[subcommand]
                end
            end
        else
            self:raise_error(string.format("command '%s' has no valid function (type: %s)", command, type(func)))
        end
    end
end
--}}}
function meta.get_use_data(self, command)
    return self.functiontable.use_data[command]
end
function meta.get_save_data(self, command)
    return self.functiontable.save_data[command]
end
function meta.get_collect_arguments(self, command)
    return self.functiontable.collect_arguments[command]
end
--{{{ get help message
function meta.get_help_message(self, command)
    local help_message = self.functiontable.help_messages[command]
    if help_message then 
        return help_message
    else
        if self.functiontable.functions[command] then
            return "no help message"
        else
            return string.format("command '%s' unknown", command)
        end
    end
end
--}}}
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
    local new_handler
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
        return self:raise_or_return_error(string.format("command '%s' already exists. Use the override flag to ignore this and install the new handler", command))
    else
        self.functiontable.functions[new_handler.command] = new_handler.action
        self.functiontable.help_messages[new_handler.command] = new_handler.help_message
        self.functiontable.save_data[new_handler.command] = new_handler.save_data
        self.functiontable.use_data[new_handler.command] = new_handler.use_data
        self.functiontable.collect_arguments[new_handler.command] = new_handler.collect_arguments
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
--{{{ check command
function meta.check_command(self, command, args)
    local func, msg = self:get_function(command, args)
    if func then
        return self:check_use_data(command)
    else
        print(msg)
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
--{{{ add options map to handler
function meta.add_options_map_to_handler(self, command, options_map)
    self.functiontable[command].options_map = options_map
end
--}}}
--}}}
--{{{ Hooks
--{{{ add hook
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
--}}}
--{{{ get hook
function meta.get_hook(self, event, command)
    if command then -- get hook tied to action
        return self.hooks[event .. ":" .. command]
    else -- get ordinary hook
        return self.hooks[event]
    end
end
--}}}
--}}}
--{{{ Error handling
--{{{ raise or return error
function meta.raise_or_return_error(self, msg)
    if self.settings.raise_errors then
        error(msg)
    else
        return nil, msg
    end
end
--}}}
--{{{ raise error
function meta.raise_error(self, msg)
    error(msg)
end
--}}}
--}}}
--{{{ Utility functions
--{{{ generate unique module name
function meta.generate_uniq_module_name(self)
    -- TODO increment a counter and return a new modulename
    return "module1"
end
--}}}
--{{{ check use data
function meta.check_use_data(self, command)
    local use_data = self:get_use_data(command)
    if use_data then
        if not self.data[use_data] then
            print(string.format("You wanted to use a action on previous data ('%s'), but there is no such data.\nMaybe you need to call some initialization function?", use_data))
            return nil
        else
            return true
        end
    else
        return true
    end
end
--}}}
--{{{ set debug mode/level
function meta.set_debug_mode(self, mode)
    self.settings.debug_mode = mode
end
--}}}
--{{{ set local debug context
function meta.set_local_debug_context(self, mode)
    self.settings.local_debug_context = mode
end
--}}}
--{{{ debug message
function meta.debug_message(self, mode_or_message, message, level)
    if pl.utils.is_type(message, "string") then
        local mode = mode_or_message
        local level = level or 0
        local indent = string.rep(" ", level)
        if mode == self.settings.debug_mode or self.settings.debug_mode == "all" then
            print(string.format("%s-> debug (%s): %s", indent, mode, message))
        end
    else -- only one argument. Use the local debugging context
        local level = message or 0 -- if a debugging context is used, the level will be given in the message argument
        local message = mode_or_message -- save message, which was given in mode argument
        local mode = self.settings.local_debug_context
        self:debug_message(mode, message, level)
    end
end
--}}}
--{{{ is hidden command
function meta.is_hidden_command(self, command)
    return string.match(command, "__[^_]+__")
end
--}}}
--{{{ is internal command
function meta.is_internal_command(self, command)
    return string.match(command, "^%" .. self.internal_command_modifier)
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
--{{{ call handler
function meta.call_handler(self, func, args)
    -- call the handler and optionally save the result
    return func(table.unpack(args))
end
--}}}
--{{{ combine arguments
function meta.combine_arguments(self, command, args)
    -- gather all arguments in one table which can be unpacked later
    local args_combined = {}
    if self.functiontable.use_data[command] then
        table.insert(args_combined, self.data[self.functiontable.use_data[command]])
    end
    -- the arguments of the function can be given sequentially or packed in a table
    -- use 'collect_arguments' to change behaviour (collect -> packed)
    if self.functiontable.collect_arguments[command] then
        table.insert(args_combined, args)
    else
        for i = 1, #args do
            table.insert(args_combined, args[i])
        end
    end

    return args_combined
end
--}}}
--{{{ strip subcommands
function meta.strip_subcommands(self, command, args)
    if self:is_supercommand(command) then
        table.remove(args, 1)
        return args
    else
        return args
    end
end
--}}}
--{{{ process arguments
function meta.process_arguments(self, command, args)
    local processed_args = self:strip_subcommands(command, args)
    processed_args = self:apply_options_to_arguments(command, processed_args)
    processed_args = self:combine_arguments(command, processed_args)

    return processed_args
end
--}}}
--{{{ prepend lookup data
function meta.prepend_lookup_data(self, action, args)
    -- FIXME: currently not used
end
--}}}
--{{{ save data
function meta.save_data(self, command, result)
    local save_data = self:get_save_data(command)
    if save_data then
        self.data[save_data] = result
    end
end
--}}}
--{{{ is supercommand
function meta.is_supercommand(self, command)
    return pl.utils.is_type(self.functiontable.functions[command], "table")
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
function meta.apply_options_to_arguments(self, command, args)
    self:set_local_debug_context("parsing")
    -- TODO: this functions needs more arguments, but i'm currently not sure which exactly
    --
    -- the following mechanisms need to be implemented:
    --      - an option generates arguments and injects them into the args table
    --      - an option causes the specified handler of an action to be called
    --      - an option calls another function before and/or after the actual action handler
    local options_map = self:get_options_map(command)
    local processed_args = {}
    if options_map then
        self:debug_message("found option map")
        for _, arg in ipairs(args) do
            if self:is_option(arg) then
                local option = self:strip_option(arg)
                -- process option
                self:debug_message(string.format("processing option: %s", option), 1)
                if options_map[option] then
                    self:debug_message(string.format("option map contains entry for option '%s'", option), 2)
                    if pl.utils.is_type(options_map[option], "string") then 
                        table.insert(processed_args, options_map[option])
                    elseif pl.utils.is_type(options_map[option], "number") then 
                    elseif pl.utils.is_type(options_map[option], "function") then 
                    elseif pl.utils.is_type(options_map[option], "table") then 
                    else 
                    end
                else
                    self:debug_message(string.format("option map contains no entry for option '%s'", option), 2)
                end
            else -- simply copy argument to final list
                table.insert(processed_args, arg)
            end
        end
    else -- no processing of arguments
        self:debug_message("no option map found")
        processed_args = args
    end
    return processed_args
end
--}}}
--{{{ get options map
function meta.get_options_map(self, command)
    return self.functiontable.options_map[command]
end
--}}}
--{{{ is option
function meta.is_option(self, argument)
    -- build matchstring
    local matchstr = "^" .. self.options_modifier .. "%w+$"
    return string.match(argument, matchstr)
end
--}}}
--{{{ strip option
function meta.strip_option(self, argument)
    -- build matchstring
    local matchstr = "[^" .. self.options_modifier .. "]"
    local _, _, option = string.find(argument, "-(.+)")
    return option
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

        if self:check_command(command, args) then -- checks for existance of the command and validity of use_data
            -- execute the 'before' hook, then the action handler, then the 'after' hook (if they exist)
            self:execute_hook("before", command)

            local func = self:get_function(command, args) -- the arguments are needed for super commands which consist of multiple handlers
            local final_args = self:process_arguments(command, args)
            local result = self:call_handler(func, final_args)
            self:save_data(command, result)

            self:execute_hook("after", command)
        end
    end
    self:execute_hook("atexit")
end
--}}}

return M

-- vim: foldmethod=marker
