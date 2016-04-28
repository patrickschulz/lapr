--{{{ Module loading
local pl   = {}
pl.file    = require "pl.file"
pl.path    = require "pl.path"
pl.dir     = require "pl.dir"
pl.tablex  = require "pl.tablex"
pl.pretty  = require "pl.pretty"
pl.utils   = require "pl.utils"
pl.stringx = require "pl.stringx"

local dp = pl.pretty.dump

local latex    = require "laprlib.latex"
local util     = require "laprlib.util"
local packages = require "laprlib.packages"
local config   = require "laprlib.config"
local debug    = require "laprlib.debug"
--}}}

local M = {}

-- metatable for project objects
local meta = util.new_metatable("projectlib")

-- load package database
-- this loads both the system and the user database
local packagelookup = packages.load()

--{{{ Object Creation Functions
--{{{ create a project
--
-- this function creates all needed files and directories for a project
-- and stores all information in the project file
--
-- parameters:
--  project name
--  initial files
--
-- project files can be added later on
function M.create(name, file_list)
    if not name then
        print("no project name given")
        return
    end
    -- arguments
    local file_list = file_list or {}

    -- object
    local self = {
        file_list = {
            main_file = "main",
            project_file = ".project",
            preamble_file = "preamble",
            table.unpack(file_list)
        },
        aux_files = { }, -- use this to save all present files while creating a project
                         -- this list is used to move or delete all unwanted files
        directories = { 
            file_dir = "files",
            image_dir = "images",
            project_dir = ".build",
        },
        last_active_file = nil,
        temporary_file = ".difftempfile", -- TODO: choose better name

        project_name = name,

        packages = {
            --{ name = "kantlipsum" }
        },

        last_edits = nil,

        -- environment
        engine = "lualatex --interaction=nonstopmode",
        editor = "vim",
        viewer = "zathura --fork",

        settings = {
            ignore_hidden = true,
            raw_output = false,
            debug = true,
        },
    }
    setmetatable(self, meta)

    self:load_config_file()

    self:create_dirs_and_files()

    return self
end
--}}}
--{{{ create standard directories and files
function meta.create_dirs_and_files(self)
    for _, dir in pairs(self.directories) do
        pl.path.mkdir(dir)
    end

    -- create files
    -- main file
    local main_content = self:get_main_content()
    util.write_tex_file(self.file_list.main_file, main_content)
    
    -- preamble
    local preamble_content = self:get_preamble_content()
    util.write_sty_file(self.file_list.preamble_file, preamble_content, self.directories.file_dir)

    -- project master file (includes all other files)
    self:write_master_file()
end
--}}}
--{{{ load config file
function meta.load_config_file(self)
    local filename = config.get_user_config_filename()
    local settings = dofile(filename)
end
--}}}
--}}}
--{{{ settings
function meta.set_editor(self, editor)
    self.editor = editor
end

function meta.set_latex_engine(self, engine)
    self.engine = engine
end

function meta.set_viewer(self, viewer)
    self.viewer = viewer
end
function meta.reset(self, mode)
    if mode == "editor" then
        self.editor = "vim"
    elseif mode == "engine" then
        self.engine = "lualatex --interaction=nonstopmode"
    elseif mode == "viewer" then
        self.viewer = "zathura --fork"
    end
end
function meta.generic_set(self, mode, ...)
    if mode == "editor" then

    elseif mode == "engine" then

    elseif mode == "viewer" then

    elseif mode == "raw" then
        if not ... then
            print(string.format("raw_output = %s", self.settings.raw_output))
        end
        self.settings.raw_output = (... and true) or false
    end
end
--}}}
--{{{ Utility Functions
--{{{ check existing project
function meta.check_existing_project(filename)
    return pl.path.exists(".project")
end
--}}}
--{{{ get full file path
function meta.get_full_file_path(self, filename)
    -- search order:
    -- 1. Main file
    -- 2. Content files
    if filename == self.file_list.main_file then
        return filename .. ".tex"
    elseif filename == self.file_list.preamble_file then
        return self.directories.file_dir .. "/" .. filename .. ".sty"
    else
        for _, file in ipairs(self.file_list) do
            if filename == file then
                return self.directories.file_dir .. "/" .. file .. ".tex"
            end
        end
    end
end
--}}}
--{{{ get filename
function meta.get_filename(self, filename)
    if not (filename or self.last_active_file) then
        return nil, "specify file to edit"
    end
    local filename = filename or self.last_active_file
    if filename == "preamble" then
        filename = self.file_list.preamble_file
    end
    filename = self:get_full_file_path(filename)
    if not filename then
        return nil, string.format("file not found in project")
    end
    return filename
end
--}}}
--{{{ info
function meta.info(self, mode)
    local indent = "  "
    print("Project Information:")
    print("---------------------------")
    print(string.format("project name:  %s", self.project_name))
    print(string.format("main file:     %s", self.file_list.main_file))
    print(string.format("preamble file: %s", self.file_list.preamble_file))
    print("content files:")
    for _, file in ipairs(self.file_list) do
        print(string.format(" -> %s", file))
    end
    print(string.format("engine: %s", self.engine))
    print(string.format("viewer: %s", self.viewer))
end
--}}}
--{{{ list packages
function meta.list_packages(self)
    for _, package in ipairs(self.packages) do
        print(package.name)
    end
end
--}}}
--{{{ compare and insert missing packages
function meta.compare_and_insert_missing_packages(self, packagelist)
    local used_packages = {}
    for _, package in ipairs(self.packages) do
        table.insert(used_packages, package.name)
    end
    local new_packages = pl.tablex.keys(pl.tablex.difference(pl.tablex.makeset(packagelist), pl.tablex.makeset(used_packages)))
    for _, package in ipairs(new_packages) do
        table.insert(self.packages, { name = package })
    end
    -- update preamble
    local preamble_content = self:get_preamble_content()
    util.write_sty_file(self.file_list.preamble_file, preamble_content, self.directories.file_dir)
end
--}}}
--}}}
--{{{ Saving/Loading Functions
--{{{ save
function meta.save(self)
    local rep = pl.pretty.write(self)
    pl.file.write(".project", rep)
end
--}}}
--{{{ load
function meta.load()
    local project_table = pl.file.read(".project")
    if not project_table then
        print("couldn't read project file ('.project')")
        return nil
    end
    local self = pl.pretty.read(project_table)
    setmetatable(self, meta)
    return self
end
--}}}
--{{{ adopt
function meta.adopt(main_file)
    local main_file = main_file or "main"
end
--}}}
--}}}
--{{{ File Functions
function meta.add_file(self, filename)
    if not filename then
        print("no filename given")
        return
    end
    if type(filename) == "table" then
        for _, fn in ipairs(filename) do
            self:add_file(fn)
        end
    else
        local content = string.format("%% %s.tex\n", filename)
        util.write_tex_file(filename, content, self.directories.file_dir)
        table.insert(self.file_list, filename)
        self:write_master_file()
        self.last_active_file = filename
    end
end

function meta.add_aux_file(self, filename)
    if type(filename) == "table" then
        for _, fn in ipairs(filename) do
            self:add_aux_file(fn)
        end
    else
        table.insert(self.aux_files, filename)
    end
end
--}}}
--{{{ Editing Functions
--{{{ create temporary copy
function meta.create_temporary_copy(self, filename)
    local ret, msg = pl.dir.copyfile(filename, self.temporary_file, true)
    if not ret then print(msg) end
end
--}}}
--{{{ delete temporary copy
function meta.delete_temporary_copy(self)
    os.remove(self.temporary_file)
end
--}}}
--{{{ get diff
function meta.get_diff(self, filename)
    local command = string.format("diff %s %s", filename, self.temporary_file)
    local status, code, stdout, stderr = pl.utils.executeex(command)
    return stdout
end
--}}}
--{{{ extract commands from diff
function meta.extract_commands_from_diff(self, diff)
    local newlines = {}
    for line in pl.stringx.lines(diff) do
        if pl.stringx.startswith(line, "<") then
            line = string.sub(line, 3)
            table.insert(newlines, line)
        end
    end
    return newlines
end
--}}}
--{{{ parse latex commands
function meta.parse_latex_commands(self, lines)
    local packagelist = {}
    for _, line in ipairs(lines) do
        for command in string.gmatch(line, "\\(%a+)") do
            local package
            if packagelookup:is_command(command) then
                package = packagelookup:get_package("commands", command)
            else
                package = packagelookup:ask_package("command", command)
                packagelookup:insert_command(command, package)
            end
            if not packagelookup:is_latex_command(command) then
                table.insert(packagelist, package)
            end
        end
        for env in string.gmatch(line, "\\begin%{([^}]+)%}") do
            local package
            if packagelookup:is_environment(env) then
                package = packagelookup:get_package("environments", env)
            else
                package = packagelookup:ask_package("environment", env)
                packagelookup:insert_environment(env, package)
            end
            if not packagelookup:is_latex_environment(env) then
                table.insert(packagelist, package)
            end
        end
    end
    return packagelist
end
--}}}
--{{{ edit preamble
function meta.edit_preamble(self)
    self:edit_file(self.file_list.preamble_file)
end
--}}}
--{{{ edit file
function meta.edit_file(self, filename)
    local filename, msg = self:get_filename(filename)
    if not filename then print(msg) return end

    -- before editing, we need to copy the file in order to make a diff after the edit
    self:create_temporary_copy(filename)

    local command = string.format("%s %s", self.editor, filename)
    os.execute(command)

    local diff = self:get_diff(filename)
    local newlines = self:extract_commands_from_diff(diff)
    local packagelist = self:parse_latex_commands(newlines)
    self:compare_and_insert_missing_packages(packagelist)

    self:delete_temporary_copy()
end
--}}}
--{{{ add package
function meta.add_package(self, package, options)
    table.insert(self.packages, { name = package, options = options })
end
--}}}
--}}}
--{{{ Document Generation Functions
function meta.compile(self, mode)
    if mode == "document" or not mode then
        local command = string.format("%s %s", self.engine, self.file_list.main_file)
        if not self.settings.raw_output then
            latex.parse_output(stdout)
            local status, code, stdout, stderr = pl.utils.executeex(command)
        else
            os.execute(command)
        end
    elseif mode == "bibtex" then

    end
end
--}}}
--{{{ Access Functions
--{{{ ignore hidden files
function meta.ignore_hidden_files(self, bool)
    self.settings.ignore_hidden = bool
end
--}}}
--{{{ enable debuggin messages
function meta.enable_debuggin_messages(self, bool)
    self.settings.debug = bool
end
--}}}
--{{{ setting
function meta.setting(self, options)
    if type(options) ~= "table" then
        print("project: setting options is not a table")
    end
end
--}}}
--}}}
--{{{ Content Generation Functions
--{{{ get main content
function meta.get_main_content(self, options)
    return string.format([[
\documentclass{scrartcl}

\usepackage{files/%s}

\begin{document}
\input{files/project_master}
\end{document}
]],
self.file_list.preamble_file)
end
--}}}
--{{{ get_master_content
function meta.get_master_content(self)
    local t = {}
    for i = 1, #self.file_list do
        t[i] = string.format("\\input{%s/%s}", self.directories.file_dir, self.file_list[i])
    end
    return table.concat(t, "\n")
end
--}}}
--{{{ get_preamble_content
function meta.get_preamble_content(self)
    local content = {
        "\\usepackage{fontspec}",
        "\\setmainfont{Linux Libertine O}",
        "\\usepackage{polyglossia}",
        "\\setdefaultlanguage{german}",
    }
    for _, package in ipairs(self.packages) do
        local packagename = package.name
        local options = package.options
        local packagestr
        if options then
            packagestr = string.format("\\usepackage[%s]{%s}", packagename, table.unpack(options, ", "))
        else
            packagestr = string.format("\\usepackage{%s}", packagename)
        end
        table.insert(content, packagestr)
    end
    return table.concat(content, "\n")
end
--}}}
--}}}
--{{{ Content Write Functions
--{{{ write master file
function meta.write_master_file(self)
    local master_content = self:get_master_content()
    util.write_tex_file("project_master", master_content, self.directories.file_dir)
end
--}}}
--}}}
--{{{ Cleanup Functions
--{{{ clean up
function meta.clean_up(self)
    -- iterate over directory and move all files NOT in the file list (or the auxiliary file list) to a hidden (or specified) directory
    local files = pl.dir.getfiles(".")
    for _, file in ipairs(files) do
        if not (util.is_hidden(file) and self.settings.ignore_hidden) then
            -- check if file is 'allowed':
            -- - it can be part of the project
            -- - it can be an auxiliary which should not be (re-)moved
            if not self:is_allowed_file(pl.path.basename(file)) then
                if self.settings.debug then
                    print(string.format("%s is not allowed and will be removed", file))
                end
                pl.file.delete(file)
            else
                if self.settings.debug then
                    print(string.format("%s is allowed", file))
                end
            end
        end
    end
end
--}}}
--{{{ purge
function meta.purge(self) -- use with care
    -- this function removes all files created by the project
    -- this includes both files created by this tool and files created by LaTeX
    local files = pl.dir.getfiles(".")
    for _, file in ipairs(files) do
        if not (util.is_hidden(file) and self.settings.ignore_hidden) then
            -- check if file is 'allowed':
            -- - it can be part of the project
            -- - it can be an auxiliary which should not be (re-)moved
            if not self:is_allowed_file(pl.path.basename(file)) then
                if self.settings.debug then
                    print(string.format("%s is not allowed and will be removed", file))
                end
                --pl.file.delete(file)
            else
                if self.settings.debug then
                    print(string.format("%s is allowed", file))
                end
            end
        end
    end
end
--}}}
--{{{ is allowed file
function meta.is_allowed_file(self, filename)
    return self:is_managed_file(filename) 
        or self:is_auxiliary_file(filename)
end
--}}}
--{{{ is managed file
function meta.is_managed_file(self, filename)
    return filename == self.file_list.main_file .. ".tex"  -- main file
        or filename == self.file_list.main_file .. ".pdf"  -- output document
        or pl.tablex.find(self.file_list, filename)        -- content file
end
--}}}
--{{{ is auxiliary file
function meta.is_auxiliary_file(self, filename)
    return pl.tablex.find(self.aux_files, filename)
end
--}}}
--}}}
--{{{ Viewing Functions
--{{{ view
function meta.view(self)
    local command = string.format("%s %s", self.viewer, self.file_list.main_file .. ".pdf")
    os.execute(command)
end
--}}}
--}}}
--{{{ Minimal session functions
-- A 'minimal' session gives to user the possibility to try out some commands while speeding up compilation time
function meta.create_minimal(self, template, options)

end

function meta.insert_minimal(self, filename)

end
--}}}
--{{{ Autocommands
-- the code typed typed the user should be logged and corrected/extended accordingly.
-- For example, if i used a tikzpicture environment and the tikz package is not yet loaded, the load code should we inserted automatically
-- For this, a big table with (ideally) all commands the user could type should be saved. Also it should be possible to add stuff to this table, for foreign
-- packages. By this, the database gets more and more accurat. In the end, maybe, one doesn't have to write the preamble by hand.
--}}}

setmetatable(M, meta)

return M

-- vim: foldmethod=marker
