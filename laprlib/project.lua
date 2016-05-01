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
function M.create(name, class, file_list)
    if not name then
        print("no project name given")
        return
    end
    -- arguments
    local file_list = file_list or {}
    local class = class or "article"

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
            minimal_dir = ".minimal",
        },
        last_active_file = nil,
        temporary_file = ".difftempfile", -- TODO: choose better name

        project_name = name,

        packages = {
            --{ name = "kantlipsum" }
            { name = "amsmath", options = { "sumlimits", "intlimits" } },
        },
        class = { class, options = {} },

        last_edits = nil,

        minimal_templates = nil,

        -- environment
        engine = { exe = "lualatex", args = "--interaction=nonstopmode" },
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
    self:load_minimal_templates()

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
-- This function is written rather explicit, one COULD use just the table loaded from the config file and insert all entries automatically.
-- But the way used here makes it possible to have a more flexible way of handling options
function meta.load_config_file(self)
    local filename = config.get_user_config_filename()
    local conf = loadfile(filename)
    if conf then
        conf = conf()
        if conf.viewer then
            self.viewer = conf.viewer
        end
        if conf.engine then
            self.engine = conf.engine
        end
        if conf.editor then
            self.editor = conf.editor
        end
        if conf.settings then
            if conf.settings.ignore_hidden then self.settings.ignore_hidden = conf.settings.ignore_hidden end
            if conf.settings.raw_output then self.settings.raw_output = conf.settings.raw_output end
            if conf.settings.debug then self.settings.debug = conf.settings.debug end
        end
        if conf.file_list then
            if conf.settings.main_file then self.settings.main_file = conf.settings.main_file end
            if conf.settings.project_file then self.settings.project_file = conf.settings.project_file end
            if conf.settings.preamble_file then self.settings.preamble_file = conf.settings.preamble_file end
        end
        if conf.directories then
            if conf.settings.file_dir then self.settings.file_dir = conf.settings.file_dir end
            if conf.settings.image_dir then self.settings.image_dir = conf.settings.image_dir end
            if conf.settings.project_dir then self.settings.project_dir = conf.settings.project_dir end
            if conf.settings.minimal_dir then self.settings.minimal_dir = conf.settings.minimal_dir end
        end
        if conf.temporary_file then 
            self.temporary_file = conf.temporary_file
        end
    else
        print("could not load user config file (perhaps you don't have one)")
    end
end
--}}}
--{{{ load minimal templates
function meta.load_minimal_templates(self)
    local filename = config.get_user_templates_filename()
    local templates = loadfile(filename)
    if templates then
        templates = templates()
        self.minimal_templates = templates
    else
        print("could not load user templates file (perhaps you don't have one)")
    end
end
--}}}
--}}}
--{{{ settings
function meta.set_class(self, class, ...)
    if class then

    else
        print(self.class)
    end
end

function meta.set_editor(self, editor)
    if editor then
        self.editor = editor
    else
        print(self.editor)
    end
end

function meta.set_latex_engine(self, engine)
    if engine then
        self.engine.exe = engine
    else
        print(self.engine.exe)
    end
end

function meta.set_viewer(self, viewer)
    self.viewer = viewer
end
function meta.reset(self, mode)
    if mode == "editor" then
        self.editor = "vim"
    elseif mode == "engine" then
        self.engine.exe = "lualatex --interaction=nonstopmode"
    elseif mode == "viewer" then
        self.viewer = "zathura --fork"
    end
end
function meta.generic_set(self, mode, ...)
    if mode == "editor" then

    elseif mode == "engine" then

    elseif mode == "viewer" then
        if not ... then
            print(string.format("pdf viewer = %s", self.viewer))
        end
    elseif mode == "raw" then
        if not ... then
            print(string.format("raw_output = %s", self.settings.raw_output))
        else
            self.settings.raw_output = (... == "true") or false
        end
    elseif mode == "class" then
        if not ... then

        else

        end
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
    print(string.format("engine: %s", self.engine.exe))
    print(string.format("viewer: %s", self.viewer))
end
--}}}
--{{{ show preamble
function meta.show_preamble(self)
    local classline = self:get_classline()
    local preamble = self:get_preamble_content()
    print(string.format("%s\n\n%s\n", classline, preamble))
end
--}}}
--{{{ list packages
function meta.list_packages(self)
    for _, package in ipairs(self.packages) do
        print(string.format("%s [%s]", package.name, table.concat(package.options, ", ")))
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
--{{{ Structuring Functions
--{{{ list structure
function meta.list_structure(self)
end
--}}}
--}}}
--{{{ Document Generation Functions
function meta.compile(self, mode)
    if mode == "document" or not mode then
        local command = string.format("%s %s %s", self.engine.exe, self.engine.args, self.file_list.main_file)
        if not self.settings.raw_output then
            local status, code, stdout, stderr = pl.utils.executeex(command)
            latex.parse_output(stdout)
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
    local classline = self:get_classline()
    return string.format([[
%s

\usepackage{%s/%s}

\begin{document}
\input{%s/project_master}
\end{document}
]],
classline,
self.directories.file_dir,
self.file_list.preamble_file,
self.directories.file_dir
)
end
--}}}
--{{{ get class line
function meta.get_classline(self)
    if self.class.options and (#self.class.options ~= 0) then
        return string.format("\\documentclass[%s]{%s}", table.concat(self.class.options, ", "), self.class[1])
    else
        return string.format("\\documentclass{%s}", self.class[1])
    end
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
    if self.engine.exe == "lualatex" then
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
                packagestr = string.format("\\usepackage[%s]{%s}", table.concat(options, ", "), packagename)
            else
                packagestr = string.format("\\usepackage{%s}", packagename)
            end
            table.insert(content, packagestr)
        end
        return table.concat(content, "\n")
    elseif self.engine.exe == "pdflatex" then
        local content = {
            "\\usepackage[utf8]{inputenc}",
            "\\usepackage[ngerman]{babel}",
        }
        for _, package in ipairs(self.packages) do
            local packagename = package.name
            local options = package.options
            local packagestr
            if options then
                packagestr = string.format("\\usepackage[%s]{%s}", table.concat(options, ", "), packagename)
            else
                packagestr = string.format("\\usepackage{%s}", packagename)
            end
            table.insert(content, packagestr)
        end
        return table.concat(content, "\n")
    else
        print(string.format("sorry, engine '%s' is not supported (yet?)", self.engine.exe))
        return "% unknown LaTeX engine"
    end
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

setmetatable(M, meta)

return M

-- vim: foldmethod=marker
